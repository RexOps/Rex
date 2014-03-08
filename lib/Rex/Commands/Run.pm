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
use Rex::Helper::Run;
use Rex::Helper::SSH2::Expect;
use Rex::Config;
use Rex::Interface::Exec;

BEGIN {
   if($^O !~ m/^MSWin/) {
      eval "use Expect";
   }
   else {
      # this fails sometimes on windows...
      eval {
         Rex::Logger::debug("Running under windows, Expect not supported.");
      };
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

If you only want to run a command in special cases, you can queue the command
and notify it when you want to run it.

 task "prepare", sub {
    run "extract-something",
       command       => "tar -C /foo -xzf /tmp/foo.tgz",
       only_notified => TRUE;

    # some code ...

    notify "run", "extract-something";   # now the command gets executed
 };

=cut

our $LAST_OUTPUT;   # this variable stores the last output of a run.
                    # so that it is possible to get for example the output of an apt-get update
                    # that is called through >> install "foo" <<

sub run {
   my $cmd = shift;
   my ($code, $option);
   if(ref $_[0] eq "CODE") {
      $code = shift;
   }
   elsif(scalar @_ > 0) {
      $option = { @_ };
   }

   if(exists $option->{command}) {
      my $notify = Rex::get_current_connection()->{notify};
      $notify->add(
         type    => "run",
         name    => $cmd,
         options => $option,
         cb      => sub {
            my ($option) = shift;
            Rex::Logger::debug("Running notified command: $cmd ($option->{command})");
            run($option->{command});
         }
      );
   }

   if(exists $option->{only_notified} && $option->{only_notified}) {
      Rex::Logger::debug("This command runs only if notified. Passing by. ($cmd, $option->{command})");
      return;
   }

   my $path;

   if(! Rex::Config->get_no_path_cleanup()) {
      $path = join(":", Rex::Config->get_path());
   }

   my $exec = Rex::Interface::Exec->create;
   my ($out, $err) = $exec->exec($cmd, $path, $option);
   chomp $out if $out;
   chomp $err if $err;

   $LAST_OUTPUT = [$out, $err];

   if(! defined $out) {
      $out = "";
   }

   if(! defined $err) {
      $err = "";
   }

   if(Rex::Config->get_exec_autodie() && Rex::Config->get_exec_autodie() == 1) {
      if($? != 0) {
         die("Error executing: $cmd.\nOutput:\n$out");
      }
   }

   if($code) {
      return &$code($out, $err);
   }

   if(wantarray) {
      return split(/\r?\n/, $out);
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

   my @ret = i_run "which $cmd";
   if($? != 0) { return 0; }

   if( grep { /^no.*in/ } @ret ) {
      return 0;
   }

   return $ret[0];
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

   my $options;
   if(ref $cmd eq "HASH") {
      $options = $cmd;
      $cmd = $options->{command};
   }

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
   my $old_options = Rex::get_current_connection()->{sudo_options} || {};
   Rex::get_current_connection()->{use_sudo} = 1;
   Rex::get_current_connection()->{sudo_options} = $options;

   my $ret;

   # if sudo is used with a code block
   if(ref($cmd) eq "CODE") {
      $ret = &$cmd();
   }
   else {
      $ret = i_run($cmd);
   }

   Rex::get_current_connection()->{use_sudo} = $old_sudo;
   Rex::get_current_connection()->{sudo_options} = $old_options;

   return $ret;
}

=back

=cut

1;
