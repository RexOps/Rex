#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Virtualization::VBox::status;

use warnings;

use Rex::Virtualization::VBox::list;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  my $vms = Rex::Virtualization::VBox::list->execute("all");

  my ($vm) = grep { $_->{name} eq $arg1 } @{$vms};

  if ( $vm->{status} eq "poweroff" ) {
    return "stopped";
  }
  else {
    return "running";
  }
}

1;
