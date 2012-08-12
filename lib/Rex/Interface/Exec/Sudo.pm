#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::Sudo;
   
use strict;
use warnings;

use Rex::Config;
use Rex::Interface::Exec::Local;
use Rex::Interface::Exec::SSH;
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

   if($path) { $path = "PATH=$path" }
   $path ||= "";

   my $exec;
   if(Rex::is_ssh()) {
      $exec = Rex::Interface::Exec->create("SSH");
   }
   else {
      $exec = Rex::Interface::Exec->create("Local");
   }

   my $sudo_password = task->get_sudo_password;
   return $exec->exec("echo '$sudo_password' | sudo -p '' -S sh -c 'LC_ALL=C $path $cmd'");
}

1;
