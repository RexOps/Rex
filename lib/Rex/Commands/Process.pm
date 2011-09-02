#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Process - Process management commands

=head1 DESCRIPTION

With this module you can manage processes. List, Kill, and so on.

=head1 SYNOPSIS

 kill $pid;
 killall "apache2";
 nice($pid, $level);

=head1 EXPORTED FUNCTIONS

=over 4

=cut



package Rex::Commands::Process;

use strict;
use warnings;

require Exporter;
use Data::Dumper;
use Rex::Commands::Run;
use Rex::Commands::Gather;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(kill killall
               ps
               nice);


=item kill($pid, $sig)

Will kill the given process id. If $sig is specified it will kill with this.

 task "kill", "server01", sub {
    kill 9931;
    kill 9931, -9;
 };

=cut

sub kill {
   my ($process, $sig) = @_;
   $sig ||= "";

   run ("kill $sig " . $process);
   if($? != 0) {
      die("Error killing $process");
   }
}

=item killall($name, $sig)

Will kill the given process. If $sig is specified it will kill with this.

 task "kill-apaches", "server01", sub {
    killall "apache2";
    killall "apache2", -9;
 };

=cut

sub killall {
   my ($process, $sig) = @_;
   $sig ||= "";

   if(can_run("killall")) {
      run ("killall $sig $process");
      if($? != 0) {
         die("Error killing $process");
      }
   }
   else {
      die("Can't execute killall.");
   }
}

=item ps

List all processes on a system. Will return all fields of a I<ps aux>.

 task "ps", "server01", sub {
    for my $process (ps()) {
      say "command  > " . $process->{"command"};
      say "pid      > " . $process->{"pid"};
      say "cpu-usage> " . $process->{"cpu"};
    }
 };

=cut

sub ps {
   my @list;
   
   if(operating_system_is("SunOS")) {
      @list = run("/usr/ucb/ps aux");
   }
   else {
      @list = run("ps aux");
   }

   if($? != 0) {
      die("Error running ps aux");
   }
   shift @list;

   my @ret = ();
   for my $line (@list) {
      my ($user, $pid, $cpu, $mem, $vsz, $rss, $tty, $stat, $start, $time, $command) = split(/\s+/, $line, 11);

      push( @ret, {
         user     => $user,
         pid      => $pid,
         cpu      => $cpu,
         mem      => $mem,
         vsz      => $vsz,
         rss      => $rss,
         tty      => $tty,
         stat     => $stat,
         start    => $start,
         time     => $time,
         command  => $command,
      });
   }

   return @ret;
}


#Will try to start a process with nohup in the background.
#
# task "start_in_bg", "server01", sub {
#    nohup "/opt/srv/myserver";
# };


#sub nohup {
#   my ($cmd) = @_;
#
#   run "nohup $cmd &";
#}

=item nice($pid, $level)

Renice a process identified by $pid with the priority $level.

 task "renice", "server01", sub {
    renice (153, -5);
 };

=cut

sub nice {
   my ($pid, $level) = @_;
   run "renice $level $pid";
   if($? != 0) {
      die("Error renicing $pid");
   }
}

=back

=cut


1;
