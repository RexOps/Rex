#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Interface::File::OpenSSH;

use warnings;

use Fcntl;
use Rex::Interface::Fs;
use Rex::Interface::File::Base;

BEGIN {
  use Rex::Require;
  Net::SFTP::Foreign::Constants->use(qw(:flags :fxp));
}

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

  Rex::Logger::debug("Opening $file with mode: $mode");

  my $sftp = Rex::get_sftp();
  if ( $mode eq ">" ) {
    $self->{fh} =
      $sftp->open( $file, SSH2_FXF_WRITE | SSH2_FXF_CREAT | SSH2_FXF_TRUNC );
  }
  elsif ( $mode eq ">>" ) {
    $self->{fh} = $sftp->open( $file, SSH2_FXF_WRITE | SSH2_FXF_APPEND );
    my $fs   = Rex::Interface::Fs->create;
    my %stat = $fs->stat($file);
    $self->{fh}->seek( $stat{size}, 0 );
  }
  elsif ( $mode eq "<" ) {
    $self->{fh} = $sftp->open( $file, SSH2_FXF_READ );
  }

  return $self->{fh};
}

sub read {
  my ( $self, $len ) = @_;

  my $sftp = Rex::get_sftp();
  my $buf = $sftp->read( $self->{fh}, $len );
  return $buf;
}

sub write {
  my ( $self, $buf ) = @_;
  my $sftp = Rex::get_sftp();
  $sftp->write( $self->{fh}, $buf );
}

sub seek {
  my ( $self, $pos ) = @_;
  my $sftp = Rex::get_sftp();
  $sftp->seek( $self->{fh}, $pos, 0 );
}

sub close {
  my ($self) = @_;
  my $sftp = Rex::get_sftp();
  $sftp->close( $self->{fh} );
}

1;
