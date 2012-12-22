#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::list;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use Data::Dumper;

sub execute {
   my ($class, $arg1, %opt) = @_;
   my @domains;

   if($arg1 eq "all") {
      @domains = run "VBoxManage list vms";
      if($? != 0) {
         die("Error running VBoxManage list vms");
      }
   } elsif($arg1 eq "running") {
      @domains = run "VBoxManage runningvms";
      if($? != 0) {
         die("Error running VBoxManage runningvms");
      }
   } else {
      return;
   }

   my @ret = ();
   for my $line (@domains) {
      my ($name, $id) = $line =~ m:^"([^"]+)"\s*\{([^\}]+)\}$:;

      my @status = grep { $_=$1 if /^VMState="([^"]+)"$/ } run "VBoxManage showvminfo \"{$id}\" --machinereadable";
      my $status;

      push( @ret, {
         id     => $id,
         name   => $name,
         status => $status[0],
      });
   }

   return \@ret;

}

1;
