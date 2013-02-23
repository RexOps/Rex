#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::Local;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Commands;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub exec {
   my ($self, $cmd, $path) = @_;

   Rex::Logger::debug("Executing: $cmd");

   my $out;

   Rex::Commands::profiler()->start("exec: $cmd");
   if($^O =~ m/^MSWin/) {
      $out = qx{$cmd};
   }
   else {
      if($path) { $path = "PATH=$path" }
      $path ||= "";

      my $new_cmd = "LC_ALL=C $path $cmd";

      if(Rex::Config->get_source_global_profile) {
         $new_cmd = ". /etc/profile; $new_cmd";
      }

      $out = qx{$new_cmd};
      $? >>= 8;
   }
   Rex::Commands::profiler()->end("exec: $cmd");

   Rex::Logger::debug($out);

   return $out;
}

1;
