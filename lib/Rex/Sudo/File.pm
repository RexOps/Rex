#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

###### DEPRECATED

package Rex::Sudo::File;

use strict;
use warnings;

# VERSION

use Rex;
use Rex::Commands;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Helper::Path;
use IO::File;

sub open {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {};

  $self->{mode}    = shift;
  $self->{file}    = shift;
  $self->{rndfile} = get_tmp_file;

  if ( my $sftp = Rex::get_sftp() ) {
    if ( $self->{mode} eq ">" ) {
      $self->{fh} =
        $sftp->open( $self->{rndfile}, O_WRONLY | O_CREAT | O_TRUNC );
    }
    elsif ( $self->{mode} eq ">>" ) {
      cp( $self->{file}, $self->{rndfile} );
      chmod( 666, $self->{rndfile} );
      $self->{fh} = $sftp->open( $self->{rndfile}, O_WRONLY | O_APPEND );
      my %stat = stat $self->{rndfile};
      $self->{fh}->seek( $stat{size} );
    }
    else {
      cp( $self->{file}, $self->{rndfile} );
      chmod( 666, $self->{rndfile} );
      $self->{fh} = $sftp->open( $self->{rndfile}, O_RDONLY );
    }
  }
  else {
    $self->{fh} = IO::File->new;
    $self->{fh}->open( $self->{mode} . " " . $self->{rndfile} );
  }

  bless( $self, $proto );

  return $self;
}

sub write {
  my ( $self, $content ) = @_;

  if ( ref( $self->{fh} ) eq "Net::SSH2::File" ) {
    $self->{fh}->write($content);
  }
  else {
    $self->{fh}->print($content);
  }
}

sub seek {
  my ( $self, $offset ) = @_;

  if ( ref( $self->{fh} ) eq "Net::SSH2::File" ) {
    $self->{fh}->seek($offset);
  }
  else {
    $self->{fh}->seek( $offset, 0 );
  }
}

sub read {
  my ( $self, $len ) = @_;
  $len ||= 64;

  my $buf;
  $self->{fh}->read( $buf, $len );

  return $buf;
}

sub close {
  my ($self) = @_;

  return unless $self->{fh};

  if ( ref( $self->{fh} ) eq "Net::SSH2::File" ) {
    $self->{fh} = undef;
  }
  else {
    $self->{fh}->close;
  }

  # use cat to not overwrite attributes/owner/group
  if ( $self->{mode} eq ">" || $self->{mode} eq ">>" ) {
    i_run "cat " . $self->{rndfile} . " >" . $self->{file};
    rm( $self->{rndfile} );
  }
}

sub DESTROY {
  my ($self) = @_;
  $self->close;
}

1;
