#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec::SSH;
   
use strict;
use warnings;

use Rex::Helper::SSH2;

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

   my $ssh = Rex::is_ssh();
   my ($out, $err) = net_ssh2_exec($ssh, "LC_ALL=C $path " . $cmd);

   Rex::Logger::debug($out);

   if(wantarray) { return ($out, $err); }

   return $out;
}

1;
