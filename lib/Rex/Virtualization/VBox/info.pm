#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::info;

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

   Rex::Logger::debug("Getting info of domain: $vmname");

   my $xml;

   my @dominfo = run "virsh dominfo $vmname";
  
   if($? != 0) {
      die("Error running virsh dominfo $vmname");
   }

   my %ret = ();
   my ($k, $v);

   for my $line (@dominfo) {
      ($k, $v) = split(/:\s+/, $line);
      $ret{$k} = $v;
   } 

   return \%ret;
}

1;
