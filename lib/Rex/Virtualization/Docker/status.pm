#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Docker::status;

use v5.12.5;
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
