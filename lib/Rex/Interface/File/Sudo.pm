#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::File::Sudo;

use strict;
use warnings;

# VERSION

use Fcntl;
use File::Basename;
require Rex::Commands;
use Rex::Interface::Fs;
use Rex::Interface::File::Base;
use Rex::Helper::Path;
use base qw(Rex::Interface::File::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub open {
  my ( $self, $mode, $file ) = @_;

  if ( my $ssh = Rex::is_ssh() ) {
    if ( ref $ssh eq "Net::OpenSSH" ) {
      $self->{fh} = Rex::Interface::File->create("OpenSSH");
    }
    else {
      $self->{fh} = Rex::Interface::File->create("SSH");
    }
  }
  else {
    $self->{fh} = Rex::Interface::File->create("Local");
  }

  # always use current logged in user for sudo fs operations
  Rex::get_current_connection_object()->push_sudo_options( {} );

  $self->{mode}    = $mode;
  $self->{file}    = $file;
  $self->{rndfile} = get_tmp_file;
  if ( $self->_fs->is_file($file) ) {

    # resolving symlinks
    while ( my $link = $self->_fs->readlink($file) ) {
      if ( $link !~ m/^\// ) {
        $file = dirname($file) . "/" . $link;
      }
      else {
        $file = $link;
      }
      $link = $self->_fs->readlink($link);
    }
    $self->{file_stat} = { $self->_fs->stat( $self->{file} ) };

    $self->_fs->cp( $file, $self->{rndfile} );
    $self->_fs->chmod( 600, $self->{rndfile} );
    $self->_fs->chown( Rex::Commands::connection->get_auth_user,
      $self->{rndfile} );
  }

  $self->{fh}->open( $mode, $self->{rndfile} );

  Rex::get_current_connection_object()->pop_sudo_options();

  return $self->{fh};
}

sub read {
  my ( $self, $len ) = @_;

  return $self->{fh}->read($len);
}

sub write {
  my ( $self, $buf ) = @_;

  utf8::encode($buf)
    if Rex::Config->get_write_utf8_files && utf8::is_utf8($buf);

  $self->{fh}->write($buf);
}

sub seek {
  my ( $self, $pos ) = @_;
  $self->{fh}->seek($pos);
}

sub close {
  my ($self) = @_;

  return unless $self->{fh};

  # always use current logged in user for sudo fs operations
  Rex::get_current_connection_object()->push_sudo_options( {} );

  $self->{fh}->close;

  if ( exists $self->{mode}
    && ( $self->{mode} eq ">" || $self->{mode} eq ">>" ) )
  {

    my $exec = Rex::Interface::Exec->create;
    if ( $self->{file_stat} ) {
      my %stat = $self->_fs->stat( $self->{file} );
      $self->_fs->chmod( $stat{mode}, $self->{rndfile} );
      $self->_fs->chown( $stat{uid}, $self->{rndfile} );
      $self->_fs->chgrp( $stat{gid}, $self->{rndfile} );
    }
    $self->_fs->rename( $self->{rndfile}, $self->{file} );

    #$exec->exec("cat " . $self->{rndfile} . " >'" . $self->{file} . "'");
  }

  $self->{fh} = undef;

  $self->_fs->unlink( $self->{rndfile} );

  Rex::get_current_connection_object()->pop_sudo_options();

  $self = undef;
}

sub _fs {
  my ($self) = @_;
  return Rex::Interface::Fs->create("Sudo");
}

1;
