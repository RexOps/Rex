#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::blklist;

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

   Rex::Logger::debug("Getting block list of domain: $vmname");

   my @blklist = run "virsh domblklist $vmname --details";

   if($? != 0) {
      die("Error running virsh domblklist $vmname");
   }

   my %ret = ();
   my ($k, $v);

   shift @blklist;
   shift @blklist;
   for my $line (@blklist) {
      my ($type, $device, $target, $source) = split(/\s+/, $line);
      $ret{$target} = {
         type => $type,
         device => $device,
         source => $source
      };
   }

   if (%options) {
      if ($options{details}) {
         my $unit = $options{unit} || 1;
         for my $target (keys %ret) {
            my @infos = run "virsh domblkinfo $vmname $target 2>/dev/null";
            if($? == 0) {
               for my $line (@infos) {
                  my ($k, $v) = split(/:\s+/, $line);
                  $ret{$target}->{$k} = $v / $unit;
               }
            }
         }
      }
   }

   return \%ret;
}

1;