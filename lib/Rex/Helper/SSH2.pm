#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Helper::SSH2;

use strict;
use warnings;

require Exporter;
use Data::Dumper;

use base qw(Exporter);

use vars qw(@EXPORT);
@EXPORT = qw(net_ssh2_exec net_ssh2_exec_output net_ssh2_shell_exec);

our $READ_STDERR = 1;

sub net_ssh2_exec {
   my ($ssh, $cmd, $callback) = @_;

   my $chan = $ssh->channel;

   # REQUIRE_TTY can be turned off by feature no_tty
   if(! Rex::Config->get_no_tty) {
      $chan->pty("vt100");
   }
   $chan->blocking(1);

   $chan->exec($cmd);

   my $in;
   my $in_err = "";

   while ( my $len = $chan->read(my $buf, 20) ) {
		$in .= $buf;
   }

   while ( my $len = $chan->read(my $buf_err, 20, 1) ) {
	    $in_err .= $buf_err;
   }

   $chan->close;
   $? = $chan->exit_status;

   # if used with $chan->pty() we have to remove \r
   if(! Rex::Config->get_no_tty) {
      $in =~ s/\r//g if $in;
      $in_err =~ s/\r//g if $in_err;
   }

   if(wantarray) {
      return ($in, $in_err);
   }

   return $in;
}

sub net_ssh2_exec_output {
   my ($ssh, $cmd, $callback) = @_;

   my $chan = $ssh->channel;
   $chan->blocking(1);

   $chan->exec($cmd);

   while(1) {
      my $buf;
      my $buf_err;
      $chan->read($buf, 15);
      $chan->read($buf_err, 15);

      if($callback) {
         &$callback($buf, $buf_err);
      } 
      else {
         print $buf;
         print $buf_err;
      }

      last unless $buf;
   }

   $chan->close;
   $? = $chan->exit_status;

}


1;
