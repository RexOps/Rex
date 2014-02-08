#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::list;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

use Data::Dumper;

sub execute {
   my ($class, $arg1, %opt) = @_;
   my $virt_settings = Rex::Config->get("virtualization");
   chomp( my $uri = ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

   my @domains;

   if($arg1 eq "all") {
      @domains = i_run "virsh -c $uri list --all";
      if($? != 0) {
         die("Error running virsh list --all");
      }
   } elsif($arg1 eq "running") {
      @domains = i_run "virsh -c $uri list";
      if($? != 0) {
         die("Error running virsh list");
      }
   } else {
      return;
   }

   ## remove header of the output
   shift @domains; shift @domains;

   my @ret = ();
   for my $line (@domains) {
      my ($id, $name, $status) = $line =~ m:^\s{0,2}(\d+|\-)\s+([A-Za-z0-9-._]+)\s+(.*)$:;

      push( @ret, {
         id     => $id,
         name   => $name,
         status => $status
      });
   }

   return \@ret;

}

1;
