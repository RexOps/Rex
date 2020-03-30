#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::File::Local;

use strict;
use warnings;

# VERSION

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

  Rex::Logger::debug("Opening $file with mode: $mode");

  open( $self->{fh}, $mode, $file ) or return;

  return 1;
}

sub read {
  my ( $self, $len ) = @_;

  my $buf;
  read( $self->{fh}, $buf, $len );
  return $buf;
}

sub write {
  my ( $self, $buf ) = @_;

  utf8::encode($buf)
    if Rex::Config->get_write_utf8_files && utf8::is_utf8($buf);

  my $fh = $self->{fh};
  print $fh $buf;
}

sub seek {
  my ( $self, $pos ) = @_;

  my $fh = $self->{fh};
  seek( $fh, $pos, 0 );
}

sub close {
  my ($self) = @_;

  my $fh = $self->{fh};
  close $fh if $fh;
  $self->{fh} = undef;
  $self = undef;
}

1;
