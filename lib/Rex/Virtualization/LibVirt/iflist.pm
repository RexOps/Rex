#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::iflist;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use Data::Dumper;

sub execute {
   shift;
   my $vmname = shift;
   my %options = @_;

   unless($vmname) {
      die("You have to define the vm name!");
   }

   Rex::Logger::debug("Getting interface list of domain: $vmname");

   my @iflist = run "virsh domiflist $vmname";

   if($? != 0) {
      die("Error running virsh domiflist $vmname");
   }

   my @ret = ();
   my ($k, $v);

   shift @iflist;
   shift @iflist;
   for my $line (@iflist) {
      my ($interface, $type, $source, $model, $mac) = split(/\s+/, $line);

      push @ret, {
         interface => $interface,
         type => $type,
         source => $source,
         model => $model,
         mac => $mac
      };
   }

   return \@ret;
}

1;