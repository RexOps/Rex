#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Run - Execute a remote command

=head1 DESCRIPTION

With this module you can run a command.

=head1 SYNOPSIS

 my $output = run "ls -l";
 sudo "id";


=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Run;

use strict;
use warnings;

require Exporter;
use Data::Dumper;
use Rex;
use Rex::Logger;
use Rex::Helper::SSH2;
use Rex::Helper::SSH2::Expect;
use Rex::Config;

BEGIN {
   if($^O !~ m/^MSWin/) {
      eval "use Expect";
   }
   else {
      Rex::Logger::debug("Running under windows, Expect not supported.");
   }
}

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(run can_run sudo);

=item run($command)

This function will execute the given command and returns the output.

 task "uptime", "server01", sub {
    say run "uptime";
 };

=cut

sub run {
   my $cmd = shift;

   Rex::Logger::debug("Running command: $cmd");

   my @ret = ();
   my $out;
   # no can_run($cmd) if there are parameters
   if(my $ssh = Rex::is_ssh()) {
      my @paths = Rex::Config->get_path;
      my $path="";
      if(@paths) {
         $path = "PATH=" . join(":", @paths);
      }
      $out = net_ssh2_exec($ssh, "LC_ALL=C $path " . $cmd);
   } else {
      if($^O =~ m/^MSWin/) {
         $out = qx{$cmd};
      }
      else {
         $out = qx{LC_ALL=C $cmd};
      }
   }

   Rex::Logger::debug($out);
   Rex::Logger::debug("Returncode: $?");

   chomp $out;

   if(wantarray) {
      return split(/\n/, $out);
   }

   return $out;
}

=item can_run($command)

This function checks if a command is in the path or is available.

 task "uptime", sub {
    if(can_run "uptime") {
       say run "uptime";
    }
 };

=cut
sub can_run {
   my $cmd = shift;

   if($^O =~ m/^MSWin/) {
      return 1;
   }

   my @ret = run "which $cmd";
   if($? != 0) { return 0; }

   if( grep { /^no.*in/ } @ret ) {
      return 0;
   }

   return 1;
}

=item sudo($command)

Run $command with I<sudo>. Define the password for sudo with I<sudo_password>.

 task "eth1-down", sub {
   sudo "ifconfig eth1 down";
 };

=cut
sub sudo {
   my ($cmd) = @_;

   my $exp;
   my $timeout       = Rex::Config->get_timeout;
   my $sudo_password = Rex::Config->get_sudo_password;

   if(my $ssh = Rex::is_ssh()) {
      $exp = Rex::Helper::SSH2::Expect->new($ssh);
   }
   else {
      if($^O =~ m/^MSWin/) {
         die("Expect not woring on windows");
      }
      else {
         $exp = Expect->new();
      }
   }

   $exp->log_stdout(0);

   my $cmd_out = "";
   $exp->log_file(sub {
      my ($str) = @_;
      $cmd_out .= $str;
   });

   $exp->spawn("sudo", $cmd);

   $exp->expect($timeout, [
                              qr/Password:|\[sudo\] password for [^:]+:/i => sub {
                                          Rex::Logger::debug("Sending password");
                                          my ($exp, $line) = @_;
                                          $exp->send($sudo_password . "\n");

                                          unless(ref($exp) eq "Rex::Helper::SSH2::Expect") {
                                             exp_continue();
                                          }
                                       },
                          ]);

   unless(ref($exp) eq "Rex::Helper::SSH2::Expect") {
      $exp->soft_close;
   }

   chomp $cmd_out;

   if(wantarray) {
      return split(/\n/, $cmd_out);
   }
   return $cmd_out;
}

=back

=cut

1;
