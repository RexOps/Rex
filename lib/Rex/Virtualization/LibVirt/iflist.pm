#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::LibVirt::iflist;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;

use Data::Dumper;
use Rex::Virtualization::LibVirt::dumpxml;

sub execute {
  shift;
  my $vmname  = shift;
  my %options = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  my $ref = Rex::Virtualization::LibVirt::dumpxml->execute($vmname);

  my $interfaces = $ref->{devices}->{interface};
  if ( ref $interfaces ne "ARRAY" ) {
    $interfaces = [$interfaces];
  }

  my %ret       = ();
  my $iface_num = 0;
  for my $iface ( @{$interfaces} ) {
    $ret{"vnet$iface_num"} = {
      type   => $iface->{model}->{type},
      source => $iface->{source}->{network},
      model  => $iface->{model}->{type},
      mac    => $iface->{mac}->{address},
    };

    $iface_num++;
  }

  return \%ret;

}

1;
