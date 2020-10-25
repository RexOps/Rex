#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::SMBios::CPU;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Inventory::SMBios::Section;
use Rex::Logger;
use base qw(Rex::Inventory::SMBios::Section);

__PACKAGE__->section("processor");

__PACKAGE__->has(
  [
    { key => 'Max Speed', from => "Maximum Speed" },
    'Family',
    { key => 'Status', from => "Processor Status" },
  ],
  1
); # is_array 1

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub num_cores {
  my ($self) = @_;
  Rex::Logger::debug("num_cores not supported");
  return -1;
}

sub get_socket_type {
  my ($self) = @_;
  Rex::Logger::debug("get_socket_type not supported");
  return;
}

1;

