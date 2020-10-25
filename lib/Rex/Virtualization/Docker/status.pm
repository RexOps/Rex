#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::status;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;
use Rex::Virtualization::Docker::list;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  my $vms = Rex::Virtualization::Docker::list->execute("all");

  my ($vm) = grep { $_->{name} eq $arg1 } @{$vms};
  return "stopped" unless $vm;

  if ( $vm->{status} =~ m/exited/i ) {
    return "stopped";
  }
  else {
    return "running";
  }
}

1;
