#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Helper::SSH2;

use strict;
use warnings;

require Exporter;

use base qw(Exporter);

use vars qw(@EXPORT);
@EXPORT = qw(net_ssh2_exec net_ssh2_exec_output);

sub net_ssh2_exec {
   my ($ssh, $cmd, $callback) = @_;

   my $chan = $ssh->channel;
   $chan->blocking(1);

   $chan->exec($cmd);

   my $in;
   while(1) {
      my $buf;
      $chan->read($buf, 20);
      $in .= $buf;

      last unless $buf;
   }

   $chan->close;
   $? = $chan->exit_status;

   return $in;
}

sub net_ssh2_exec_output {
   my ($ssh, $cmd, $callback) = @_;

   my $chan = $ssh->channel;
   $chan->blocking(1);

   $chan->exec($cmd);

   my $in;
   while(1) {
      my $buf;
      $chan->read($buf, 15);

      if($callback) {
         &$callback($buf);
      } 
      else {
         print $buf;
      }

      last unless $buf;
   }

   $chan->close;
   $? = $chan->exit_status;

   return $in;

}


1;
