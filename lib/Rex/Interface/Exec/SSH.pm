#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::SSH;
   
use strict;
use warnings;

use Rex::Helper::SSH2;
use File::Basename 'basename';
use Rex::Interface::Shell;
require Rex::Commands;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub exec {
   my ($self, $cmd, $path, $option) = @_;

   if(exists $option->{cwd}) {
      $cmd = "cd " . $option->{cwd} . " && $cmd";
   }

   Rex::Logger::debug("Executing: $cmd");

   Rex::Commands::profiler()->start("exec: $cmd");

   my $used_shell = $self->_get_shell();

   my $shell = Rex::Interface::Shell->create($used_shell);

   $shell->set_locale("C");
   $shell->path($path);

   if(Rex::Config->get_source_global_profile) {
       $shell->parse_profile(1);
   }

   my $exec = $shell->exec($cmd);
   Rex::Logger::debug("SSH/executing: $exec");
   my ($out, $err) = $self->_exec($exec);

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

sub _exec {
   my ($self, $exec) = @_;
   
   my $ssh = Rex::is_ssh();
   my ($out, $err) = net_ssh2_exec($ssh, $exec);

   return ($out, $err);
}

sub _get_shell {
   my ($self) = @_;

   my ($shell_path) = $self->_exec("echo \$SHELL");
   chomp $shell_path;
   my $used_shell = basename($shell_path);

   return $used_shell;
}

1;
