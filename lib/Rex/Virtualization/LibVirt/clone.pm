#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::clone;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
  my ( $class, $vmname, $newname ) = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  unless ($newname) {
    die("You have to define the new vm name!");
  }

  my $connect = Rex::Config->get('virtualization')->{connect};

  i_run
    "/usr/bin/virt-clone --connect '$connect' -o '$vmname' -n '$newname' --auto-clone";
}

1;
