#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::share_folder;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Virtualization::VBox::info;

#
# vm share_folder => "foovm", add => { sharename => "/host/path" };
# vm share_folder => "foovm", remove => "sharename";
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
      FOLDER: for my $folder (keys %{ $option }) {
         my $info = Rex::Virtualization::VBox::info->execute($dom);
         my @keys = grep { m/^SharedFolderNameMachineMapping/ } keys %{ $info };
         for my $k (@keys) {
            if($info->{$k} eq $folder) {
               # folder already mapped
               next FOLDER;
            }
         }

         my $from_path = $option->{$folder};
         run "VBoxManage sharedfolder add \"$dom\" --name \"$folder\" --automount --hostpath \"$from_path\"";
      }
   }
   else {
      if($option ne "-all") {
         run "VBoxManage sharedfolder remove \"$dom\" --name \"$option\"";
      }
      else {
         # if no name is given, remove all redirects
         # output: SharedFolderNameMachineMapping1
         my $info = Rex::Virtualization::VBox::info->execute($dom);
         my @keys = grep { m/^SharedFolderNameMachineMapping/ } keys %{ $info };

         for my $k (@keys) {
            run "VBoxManage sharedfolder delete \"$dom\" --name \"$info->{$k}\"";
         }
      }
      
   }

   if($? != 0) {
      die("Error setting folder shares for vm $dom");
   }

}

1;


