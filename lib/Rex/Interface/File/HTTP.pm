#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::File::HTTP;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;

BEGIN {
  use Rex::Require;
  MIME::Base64->use;
}

use Rex::Commands;
use Rex::Interface::Fs;
use Rex::Interface::File::Base;
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

  $self->{__file}        = $file;
  $self->{__current_pos} = 0;

  if ( $mode eq ">>" ) {
    my $fs = Rex::Interface::Fs->create;
    eval {
      my %stat = $fs->stat($file);
      $self->{__current_pos} = $stat{size};
    };
  }

  Rex::Logger::debug("Opening $file with mode: $mode");
  my $resp = connection->post( "/file/open", { path => $file, mode => $mode } );
  return $resp->{ok};
}

sub read {
  my ( $self, $len ) = @_;

  my $resp = connection->post(
    "/file/read",
    {
      path  => $self->{__file},
      start => $self->{__current_pos},
      len   => $len,
    }
  );

  if ( $resp->{ok} ) {
    my $buf = decode_base64( $resp->{buf} );
    $self->{__current_pos} += length($buf);
    return $buf;
  }

  return;
}

sub write {
  my ( $self, $buf ) = @_;

  utf8::encode($buf)
    if Rex::Config->get_write_utf8_files && utf8::is_utf8($buf);

  my $resp = connection->post(
    "/file/write_fh",
    {
      path  => $self->{__file},
      start => $self->{__current_pos},
      buf   => encode_base64($buf),
    }
  );

  if ( $resp->{ok} ) {
    $self->{__current_pos} += length($buf);
    return length($buf);
  }

  return;
}

sub seek {
  my ( $self, $pos ) = @_;
  $self->{__current_pos} = $pos;
}

sub close {
  my ($self) = @_;

  delete $self->{__current_pos};
  delete $self->{__file};
}

1;
