#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Cache::Base;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub gen_key_name {
  my ( $self, $key_name ) = @_;
  return $key_name if $key_name;

  my ( $package, $filename, $line, $subroutine ) = caller(1);

  $package =~ s/::/_/g;

  my $gen_key_name = "\L${package}_\L${subroutine}";

  return $gen_key_name;
}

sub set {
  my ( $self, $key, $val, $timeout ) = @_;

  if ( Rex::Config->get_use_cache ) {
    $self->{__data__}->{$key} = $val;
  }
}

sub valid {
  my ( $self, $key ) = @_;
  return exists $self->{__data__}->{$key};
}

sub get {
  my ( $self, $key ) = @_;
  return $self->{__data__}->{$key};
}

sub reset {
  my ($self) = @_;
  $self->{__data__} = {};
}

# have to be overwritten by subclass
sub save {
  my ($self) = @_;
  return 1;
}

# have to be overwritten by subclass
sub load {
  my ($self) = @_;
  return 0;
}

1;
