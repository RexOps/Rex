#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::info;

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

   my @dominfo = run "VBoxManage showvminfo '$vmname' --machinereadable";
  
   if($? != 0) {
      die("Error running VBoxManage showvminfo $vmname");
   }

   my %ret = ();
   my ($k, $v);

   for my $line (@dominfo) {
      ($k, $v) = split(/=/, $line);
      $k =~ s/^"|"$//g;
      $v =~ s/^"|"$//g;
      $ret{$k} = $v;
   } 

   return \%ret;
}

1;
