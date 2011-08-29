#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virt::list;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use Data::Dumper;

sub execute {
   my ($class, $arg1, %opt) = @_;
   my @domains;

   if($arg1 eq "all") {
      @domains = run "virsh list --all";
      if($? != 0) {
         die("Error running virsh list --all");
      }
   } elsif($arg1 eq "running") {
      @domains = run "virsh list";
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
