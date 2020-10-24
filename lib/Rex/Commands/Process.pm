#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Process - Process management commands

=head1 DESCRIPTION

With this module you can manage processes. List, Kill, and so on.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 SYNOPSIS

 kill $pid;
 killall "apache2";
 nice($pid, $level);

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Process;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use Data::Dumper;
use Rex::Helper::Run;
use Rex::Commands::Gather;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(kill killall
  ps
  nice);

=head2 kill($pid, $sig)

Will kill the given process id. If $sig is specified it will kill with the given signal.

 task "kill", "server01", sub {
   kill 9931;
   kill 9931, -9;
 };

=cut

sub kill {
  my ( $process, $sig ) = @_;
  $sig ||= "";

  i_run( "kill $sig " . $process, fail_ok => 1 );
  if ( $? != 0 ) {
    die("Error killing $process");
  }
}

=head2 killall($name, $sig)

Will kill the given process. If $sig is specified it will kill with the given signal.

 task "kill-apaches", "server01", sub {
   killall "apache2";
   killall "apache2", -9;
 };

=cut

sub killall {
  my ( $process, $sig ) = @_;
  $sig ||= "";

  if ( can_run("killall") ) {
    i_run( "killall $sig $process", fail_ok => 1 );
    if ( $? != 0 ) {
      die("Error killing $process");
    }
  }
  else {
    die("Can't execute killall.");
  }
}

=head2 ps

List all processes on a system. Will return all fields of a I<ps aux>.

 task "ps", "server01", sub {
   for my $process (ps()) {
    say "command  > " . $process->{"command"};
    say "pid    > " . $process->{"pid"};
    say "cpu-usage> " . $process->{"cpu"};
   }
 };


On most operating systems it is also possible to define custom parameters for ps() function.

 task "ps", "server01", sub {
   my @list = grep { $_->{"ni"} == -5 } ps("command","ni");
 };

This example would contain all processes with a nice of -5.


=cut

sub ps {
  my (@custom) = @_;
  my @list;

  if (is_openwrt) {

    # openwrt doesn't have ps aux
    @list = i_run( "ps", fail_ok => 1 );

    my @ret = ();
    for my $line (@list) {
      $line =~ s/^\s*|\s*$//g;
      my ( $pid, $user, $vsz, $stat, $command ) = split( /\s+/, $line, 5 );

      push(
        @ret,
        {
          user    => $user,
          pid     => $pid,
          vsz     => $vsz,
          stat    => $stat,
          command => $command,
        }
      );
    }

    return @ret;
  }

  elsif ( operating_system_is("SunOS") && operating_system_version() <= 510 ) {
    if (@custom) {
      @list =
        i_run( "/usr/ucb/ps awwx -o" . join( ",", @custom ), fail_ok => 1 );
    }
    else {
      @list = i_run( "/usr/ucb/ps auwwx", fail_ok => 1 );
    }
  }
  else {
    if (@custom) {
      @list = i_run( "ps awwx -o" . join( ",", @custom ), fail_ok => 1 );
    }
    else {
      @list = i_run( "ps auwwx", fail_ok => 1 );
    }
  }

  if ( $? != 0 ) {
    if (@custom) {
      die( "Error running ps ax -o" . join( ",", @custom ) );
    }
    else {
      die("Error running ps aux");
    }
  }
  shift @list;

  my @ret = ();
  if (@custom) {
    for my $line (@list) {
      $line =~ s/^\s+//;
      my @col_vals = split( /\s+/, $line, scalar(@custom) );
      my %vals;
      @vals{@custom} = @col_vals;
      push @ret, {%vals};
    }
  }
  else {
    for my $line (@list) {
      my (
        $user, $pid,  $cpu,   $mem,  $vsz, $rss,
        $tty,  $stat, $start, $time, $command
      ) = split( /\s+/, $line, 11 );

      push(
        @ret,
        {
          user    => $user,
          pid     => $pid,
          cpu     => $cpu,
          mem     => $mem,
          vsz     => $vsz,
          rss     => $rss,
          tty     => $tty,
          stat    => $stat,
          start   => $start,
          time    => $time,
          command => $command,
        }
      );
    }
  }

  return @ret;
}

#Will try to start a process with nohup in the background.
#
# task "start_in_bg", "server01", sub {
#   nohup "/opt/srv/myserver";
# };

#sub nohup {
#  my ($cmd) = @_;
#
#  run "nohup $cmd &";
#}

=head2 nice($pid, $level)

Renice a process identified by $pid with the priority $level.

 task "renice", "server01", sub {
   nice (153, -5);
 };

=cut

sub nice {
  my ( $pid, $level ) = @_;
  i_run "renice $level $pid", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error renicing $pid");
  }
}

1;
