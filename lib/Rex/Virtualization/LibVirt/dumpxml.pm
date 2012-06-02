#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::dumpxml;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
   my ($class, $vmname) = @_;

   unless($vmname) {
      die("You have to define the vm name!");
   }

   Rex::Logger::debug("Getting dumpxml of domain: $vmname");

   my $xml;

   my $dumpxml = run "virsh dumpxml $vmname";
  
   if($? != 0) {
      die("Error running virsh dumpxml $vmname");
   }
   return XMLin($dumpxml);
}

1;
