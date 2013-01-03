#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::forward_port;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Virtualization::VBox::info;

#
# vm forward_port => "foovm", add => { http => [80, 90] };
# vm forward_port => "foovm", remove => "http";
#

sub execute {
   my ($class, $arg1, $action, $option) = @_;

   unless($arg1) {
      die("You have to define the vm name!");
   }

   my $dom = $arg1;

   unless($dom) {
      die("VM $dom not found.");
   }

   if($action eq "add") {
      for my $rule (keys %{ $option }) {


         my $from_port = $option->{$rule}->[0];
         my $to_port = $option->{$rule}->[1];

         run "VBoxManage modifyvm \"$dom\" --natpf1 \"$rule,tcp,,$from_port,,$to_port\"";
      }
   }
   else {
      if($option ne "-all") {
         run "VBoxManage modifyvm \"$dom\" --natpf1 delete \"$option\"";
      }
      else {
         # if no name is given, remove all redirects
         # output: Forwarding(0)="ssh,tcp,,2222,,22"
         my $info = Rex::Virtualization::VBox::info->execute($dom);
         my @keys = grep { m/^Forwarding/ } keys %{ $info };

         for my $k (@keys) {
            my @_t = split(/,/, $info->{$k});
            run "VBoxManage modifyvm \"$dom\" --natpf1 delete \"$_t[0]\"";
         }
      }
      
   }

   if($? != 0) {
      die("Error setting port forwarding options for vm $dom");
   }

}

1;


