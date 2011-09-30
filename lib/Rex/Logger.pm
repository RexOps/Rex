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

my $log_opened = 0;

sub init {
   eval {
      die if(Rex::Config->get_log_filename);
      require Sys::Syslog;
      Sys::Syslog->import;
      openlog("rex", "ndelay,pid", Rex::Config->get_log_facility);
      $has_syslog = 1;
   };

   if($@) {
      open($log_fh, ">>", (Rex::Config->get_log_filename() . "-$$" || "rex-$$.log")) or die($!);
   }

   $log_opened = 1;
}

sub info {
   my ($msg) = @_;

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   unless($log_opened) {
      init();
      $log_opened = 2;
   }

   if($has_syslog) {
      syslog("info", $msg);
   }
   else {
      print {$log_fh} "[" . get_timestamp() . "] ($$) INFO - $msg\n" if($log_fh);
   }

   print STDERR "[" . get_timestamp() . "] ($$) - INFO - $msg\n" unless($::QUIET);

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   if($log_opened == 2) {
      &shutdown();
   }
}

sub debug {
   my ($msg) = @_;
   return unless $debug;

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   unless($log_opened) {
      init();
      $log_opened = 2;
   }

   if($has_syslog) {
      syslog("debug", $msg);
   }
   else {
      print {$log_fh} "[" . get_timestamp() . "] ($$) DEBUG - $msg\n" if($log_fh);
   }
   
   print STDERR "[" . get_timestamp() . "] ($$) DEBUG - $msg\n" unless($::QUIET);

   # workaround for windows Sys::Syslog behaviour on forks
   # see: #6
   if($log_opened == 2) {
      &shutdown();
   }
}

sub get_timestamp {
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $mon++;
   $year += 1900;

   return "$year-" . sprintf("%02i", $mon) . "-" . sprintf("%02i", $mday) . " " . sprintf("%02i", $hour) . ":" . sprintf("%02i", $min) . ":" . sprintf("%02i", $sec);
}

sub shutdown {
   return unless $log_opened;

   if($has_syslog) {
      closelog();
   }
   else {
      close($log_fh) if $log_fh;
   }

   $log_opened = 0;
  
}

1;
