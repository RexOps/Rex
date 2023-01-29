#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::LibVirt::clone;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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
