#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Logger;

use strict;
use warnings;

my $has_syslog = 0;
my $log_fh;
our $debug = 0;

sub init {
   eval {
      die if(Rex::Config->get_log_filename);
      require Sys::Syslog;
      Sys::Syslog->import;
      openlog("rex", "ndelay,pid", "local0");
      $has_syslog = 1;
   };

   if($@) {
      open($log_fh, ">>", (Rex::Config->get_log_filename || 'rex.log')) or die($!);
   }
}

sub info {
   my ($msg) = @_;

   if($has_syslog) {
      syslog((Rex::Config->get_log_priority || "info"), $msg);
   }
   else {
      print {$log_fh} "[" . get_timestamp() . "] $msg\n" if($log_fh);
   }

   print STDERR "[" . get_timestamp() . "] - INFO - $msg\n";
}

sub debug {
   my ($msg) = @_;
   return unless $debug;

   if($has_syslog) {
      syslog("debug", $msg);
   }
   else {
      print {$log_fh} "[" . get_timestamp() . "] DEBUG - $msg\n" if($log_fh);
   }
   
   print STDERR "[" . get_timestamp() . "] DEBUG - $msg\n";
}

sub get_timestamp {
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $mon++;
   $year += 1900;

   return "$year-" . sprintf("%02i", $mon) . sprintf("%02i", $mday) . " " . sprintf("%02i", $hour) . ":" . sprintf("%02i", $min) . ":" . sprintf("%02i", $sec);
}

END {
   if($has_syslog) {
      closelog();
   }
   else {
      close($log_fh) if $log_fh;
   }
};

1;
