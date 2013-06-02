#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::guestinfo;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Virtualization::LibVirt::iflist;

sub execute {
   my ($class, $vmname) = @_;

   unless($vmname) {
      die("You have to define the vm name!");
   }

   Rex::Logger::debug("Getting info of guest: $vmname");

   my $ifs = Rex::Virtualization::LibVirt::iflist->execute($vmname);

   my %arp = map { my @x = ( $_ =~ m/\(([^\)]+)\) at ([^\s]+)\s/ ); ($x[1], $x[0]) } run "/usr/sbin/arp -an";

   my @ifaces;
   for my $if (keys %{ $ifs }) {
      push @ifaces, {
         device => $if,
         ip   => $arp{$ifs->{$if}->{mac}} || "",
         %{ $ifs->{$if} }
      };
   }

   return {
      network => \@ifaces,
   };
}

1;
