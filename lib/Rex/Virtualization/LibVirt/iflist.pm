#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::iflist;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Helper::Run;

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

__END__

  print Dumper($ref);
return;
  Rex::Logger::debug("Getting interface list of domain: $vmname");

  my @iflist = i_run "virsh domiflist $vmname";

  if($? != 0) {
    die("Error running virsh domiflist $vmname");
  }

  my ($k, $v);

  shift @iflist;
  shift @iflist;
  my $iface_num = 0;
  for my $line (@iflist) {
    my ($interface, $type, $source, $model, $mac) = split(/\s+/, $line);

    if($interface eq "-") {
      $interface = "vnet$iface_num";
    }

    $ret{$interface} = {
      type => $type,
      source => $source,
      model => $model,
      mac => $mac
    };

    $iface_num++;
  }

  return \%ret;
}

1;
