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

#require Exporter;
require Rex::Exporter;
use Data::Dumper;
use Rex;
use Rex::Logger;
use Rex::Helper::SSH2;
use Rex::Helper::SSH2::Expect;
use Rex::Config;
use Rex::Interface::Exec;

BEGIN {
   if($^O !~ m/^MSWin/) {
      eval "use Expect";
   }
   else {
      Rex::Logger::debug("Running under windows, Expect not supported.");
   }
}

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(run can_run sudo);

=item run($command [, $callback])

This function will execute the given command and returns the output.

 task "uptime", "server01", sub {
    say run "uptime";
    run "uptime", sub {
       my ($stdout, $stderr) = @_;
       my $server = Rex::get_current_connection()->{server};
       say "[$server] $stdout\n";
    };
 };

=cut

sub run {
   my ($cmd, $code) = @_;

   my $path = join(":", Rex::Config->get_path());

   my $exec = Rex::Interface::Exec->create;
   my ($out, $err) = $exec->exec($cmd, $path);
   chomp $out if $out;
   chomp $err if $err;

   if($code) {
      return &$code($out, $err);
   }

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

   if(! Rex::is_ssh() && $^O =~ m/^MSWin/) {
      return 1;
   }

   my @ret = run "which $cmd";
   if($? != 0) { return 0; }

   if( grep { /^no.*in/ } @ret ) {
      return 0;
   }

   return 1;
}

=item sudo

Run a command with I<sudo>. Define the password for sudo with I<sudo_password>.

You can use this function to run one command with sudo privileges or to turn on sudo globaly.

 user "unprivuser";
 sudo_password "f00b4r";
 sudo -on;   # turn sudo globaly on
     
 task prepare => sub {
    install "apache2";
    file "/etc/ntp.conf",
       source => "files/etc/ntp.conf",
       owner  => "root",
       mode   => 640;
 };

Or, if you don't turning sudo globaly on.

 task prepare => sub {
    file "/tmp/foo.txt",
       content => "this file was written without sudo privileges\n";
        
    # everything in this section will be executed with sudo privileges
    sudo sub {
       install "apache2";
       file "/tmp/foo2.txt",
          content => "this file was written with sudo privileges\n";
    };
 };

Run only one command within sudo.

 task "eth1-down", sub {
   sudo "ifconfig eth1 down";
 };

=cut
sub sudo {
   my ($cmd) = @_;

   if($cmd eq "on" || $cmd eq "-on" || $cmd eq "1") {
      Rex::Logger::debug("Turning sudo globaly on");
      Rex::global_sudo(1);
      return;
   }
   elsif($cmd eq "0") {
      Rex::Logger::debug("Turning sudo globaly off");
      Rex::global_sudo(0);
      return;
   }

   my $old_sudo = Rex::get_current_connection()->{use_sudo} || 0;
   Rex::get_current_connection()->{use_sudo} = 1;

   my $ret;

   # if sudo is used with a code block
   if(ref($cmd) eq "CODE") {
      $ret = &$cmd();
   }
   else {
      $ret = run($cmd);
   }

   Rex::get_current_connection()->{use_sudo} = $old_sudo;

   return $ret;
}

=back

=cut

1;
