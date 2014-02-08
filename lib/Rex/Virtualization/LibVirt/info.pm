#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::info;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
   my ($class, $vmname) = @_;
   my $virt_settings = Rex::Config->get("virtualization");
   chomp( my $uri = ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

   unless($vmname) {
      die("You have to define the vm name!");
   }

   Rex::Logger::debug("Getting info of domain: $vmname");

   my $xml;

   my @dominfo = i_run "virsh -c $uri dominfo $vmname";
  
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
