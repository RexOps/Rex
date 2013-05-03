#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::SSH;
   
use strict;
use warnings;

use Rex::Helper::SSH2;
require Rex::Commands;

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

   if($path) { $path = "PATH=$path" }
   $path ||= "";

   Rex::Commands::profiler()->start("exec: $cmd");

   my $ssh = Rex::is_ssh();

   my ($shell) = net_ssh2_exec($ssh, "echo \$SHELL");
   $shell ||= "bash";

   my ($out, $err);
   if($shell !~ m/\/bash/ && $shell !~ m/\/sh/) {
      ($out, $err) = net_ssh2_exec($ssh, $cmd);
   }
   else {

      my $new_cmd = "LC_ALL=C $cmd";
      if($path) {
         $new_cmd = "export $path ; $new_cmd";
      }

      if(Rex::Config->get_source_global_profile) {
         $new_cmd = ". /etc/profile >/dev/null 2>&1; $new_cmd";
      }

      Rex::Logger::debug("SSH/executing: >$new_cmd<");
      ($out, $err) = net_ssh2_exec($ssh, $new_cmd);
   }

   Rex::Commands::profiler()->end("exec: $cmd");

   Rex::Logger::debug($out) if ($out);
   if($err) {
      Rex::Logger::debug("========= ERR ============");
      Rex::Logger::debug($err);
      Rex::Logger::debug("========= ERR ============");
   }

   if(wantarray) { return ($out, $err); }

   return $out;
}

1;
