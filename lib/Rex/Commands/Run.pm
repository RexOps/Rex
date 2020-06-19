#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Run - Execute a remote command

=head1 DESCRIPTION

With this module you can run a command.

=head1 SYNOPSIS

 my $output = run "ls -l";
 sudo "id";


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Run;

use strict;
use warnings;

# VERSION

#require Exporter;
require Rex::Exporter;
use Net::OpenSSH::ShellQuoter;
use Data::Dumper;
use Rex;
use Rex::Logger;
use Rex::Helper::SSH2;
use Rex::Helper::Run;
use Rex::Helper::SSH2::Expect;
use Rex::Config;
use Rex::Interface::Exec;
use Rex::Interface::Fs;

BEGIN {
  if ( $^O !~ m/^MSWin/ ) {
    eval "use Expect";
  }
  else {
    # this fails sometimes on windows...
    eval {
      Rex::Logger::debug("Running under windows, Expect not supported."); };
  }
}

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(run can_run sudo);

=head2 run($command [, $callback], %options)

=head2 run($command, $arguments, %options)

This form will execute $command with the given $arguments.
$arguments must be an array reference. The arguments will be quoted.

 run "ls", ["-l", "-t", "-r", "-a"];
 run "ls", ["/tmp", "-l"], auto_die => TRUE;

=head2 run($command_description, command => $command, %options)

This function will execute the given command and returns the output. In
scalar context it returns the raw output as is, and in list context it
returns the list of output lines. The exit value of the command is stored
in the $? variable.


 task "uptime", "server01", sub {
   say run "uptime";
   run "uptime", sub {
     my ($stdout, $stderr) = @_;
     my $server = Rex::get_current_connection()->{server};
     say "[$server] $stdout\n";
   };
 };

Supported options are:

  cwd             => $path
    sets the working directory of the executed command to $path
  only_if         => $condition_command
    executes the command only if $condition_command completes successfully
  unless          => $condition_command
    executes the command unless $condition_command completes successfully
  only_notified   => TRUE
    queues the command, to be executed upon notification (see below)
  env             => { var1 => $value1, ..., varN => $valueN }
    sets environment variables in the environment of the command
  timeout         => value
    sets the timeout for the command to be run
  auto_die        => TRUE
    die if the command returns with a non-zero exit code
    it can be set globally via the exec_autodie feature flag
  command         => $command_to_run
    if set, run tries to execute the specified command and the first argument
    becomes an identifier for the run block (e.g. to be triggered with notify)
  creates         => $file_to_create
    tries to create $file_to_create upon execution
    skips execution if the file already exists
  continuous_read => $callback
    calls $callback subroutine reference for each line of the command's output,
    passing the line as an argument

Examples:

If you only want to run a command in special cases, you can queue the command
and notify it when you want to run it.

 task "prepare", sub {
   run "extract-something",
     command     => "tar -C /foo -xzf /tmp/foo.tgz",
     only_notified => TRUE;

   # some code ...

   notify "run", "extract-something";  # now the command gets executed
 };

If you only want to run a command if another command succeeds or fails, you can use
I<only_if> or I<unless> option.

 run "some-command",
   only_if => "ps -ef | grep -q httpd";   # only run if httpd is running

 run "some-other-command",
   unless => "ps -ef | grep -q httpd";    # only run if httpd is not running

If you want to set custom environment variables you can do it like this:

 run "my_command",

    env => {
     env_var_1 => "the value for 1",
     env_var_2 => "the value for 2",
   };

If you want to end the command upon receiving a certain output:
 run "my_command",
   end_if_matched => qr/PATTERN/;
   
=cut

our $LAST_OUTPUT; # this variable stores the last output of a run.
                  # so that it is possible to get for example the output of an apt-get update
                  # that is called through >> install "foo" <<

sub run {
  my $cmd = shift;

  if ( ref $cmd eq "ARRAY" ) {
    for my $_cmd ( @{$cmd} ) {
      &run( $_cmd, @_ );
    }
    return;
  }

  my ( $code, $option );
  if ( ref $_[0] eq "CODE" ) {
    $code = shift;
  }

  my ($args);
  if ( ref $_[0] eq "ARRAY" ) {
    $args = shift;
  }

  if ( scalar @_ > 0 ) {
    $option = {@_};
  }

  $option->{auto_die} = Rex::Config->get_exec_autodie()
    if !exists $option->{auto_die};

  my $res_cmd = $cmd;

  if ( exists $option->{only_notified} && $option->{only_notified} ) {
    Rex::Logger::debug(
      "This command runs only if notified. Passing by. ($cmd, $option->{command})"
    );
    my $notify = Rex::get_current_connection()->{notify};
    $notify->add(
      type    => "run",
      name    => $cmd,
      options => $option,
      cb      => sub {
        my ($option) = shift;
        Rex::Logger::debug(
          "Running notified command: $cmd ($option->{command})");
        run( $option->{command} );
      }
    );

    return;
  }

  if ( exists $option->{command} ) {
    $cmd = $option->{command};
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "run", name => $res_cmd );

  my $changed = 1; # default for run() is 1

  if ( exists $option->{creates} ) {
    my $fs = Rex::Interface::Fs->create();
    if ( $fs->is_file( $option->{creates} ) ) {
      Rex::Logger::debug(
        "File $option->{creates} already exists. Not executing $cmd.");
      $changed = 0;
    }
  }

  if ( exists $option->{only_if} ) {
    run( $option->{only_if}, auto_die => 0 );
    if ( $? != 0 ) {
      Rex::Logger::debug(
        "Don't executing $cmd because $option->{only_if} return $?.");
      $changed = 0;
      $?       = 0; # reset $?
    }
  }

  if ( exists $option->{unless} ) {
    run( $option->{unless}, auto_die => 0 );
    if ( $? == 0 ) {
      Rex::Logger::debug(
        "Don't executing $cmd because $option->{unless} return $?.");
      $changed = 0;
    }
  }

  my $out_ret;
  my ( $out, $err );

  if ($changed) {
    my $path;

    if ( !Rex::Config->get_no_path_cleanup() ) {
      $path = join( ":", Rex::Config->get_path() );
    }

    my $exec = Rex::Interface::Exec->create;

    if ( $args && ref($args) eq "ARRAY" ) {
      my $quoter = Net::OpenSSH::ShellQuoter->quoter( $exec->shell->name );
      $cmd = "$cmd " . join( " ", map { $quoter->quote($_) } @{$args} );
    }

    if ( exists $option->{timeout} && $option->{timeout} > 0 ) {
      eval {
        local $SIG{ALRM} = sub { die("timeout"); };
        alarm $option->{timeout};
        ( $out, $err ) = $exec->exec( $cmd, $path, $option );
        alarm 0;
      };

      if ( $@ =~ m/^timeout at/ ) {
        Rex::Logger::info( "Timeout executing $cmd.", "error" );
        $? = 300;
      }
    }
    else {
      ( $out, $err ) = $exec->exec( $cmd, $path, $option );
    }

    chomp $out if $out;
    chomp $err if $err;

    $LAST_OUTPUT = [ $out, $err ];

    if ( !defined $out ) {
      $out = "";
    }

    if ( !defined $err ) {
      $err = "";
    }

    if ( $? == 127 ) {
      Rex::Logger::info( "$cmd: Command not found.", "error" )
        if ( Rex::Config->get_verbose_run );
    }
    elsif ( $? != 0 && $? != 300 ) {
      Rex::Logger::info( "Error executing $cmd: Return code: $?", "warn" )
        if ( Rex::Config->get_verbose_run );
    }
    elsif ( $? == 0 ) {
      Rex::Logger::info("Successfully executed $cmd.")
        if ( Rex::Config->get_verbose_run );
    }

    if ($code) {
      $out_ret = &$code( $out, $err );
    }

    else {
      $out_ret = $out;
    }

    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Command ($cmd) executed. Return code: $?"
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "run", name => $res_cmd );

  if ( exists $option->{auto_die} && $option->{auto_die} ) {
    if ( $? != 0 ) {
      die("Error executing: $cmd.\nSTDOUT:\n$out\nSTDERR:\n$err");
    }
  }

  if ( wantarray && defined $out_ret ) {
    return split( /\r?\n/, $out_ret );
  }

  return $out_ret;
}

=head2 can_run($command)

This function checks if a command is in the path or is available. You can
specify multiple commands, the first command found will be returned.

 task "uptime", sub {
   if( my $cmd = can_run("uptime", "downtime") ) {
     say run $cmd;
   }
 };

=cut

sub can_run {
  my @commands = @_;
  my $exec     = Rex::Interface::Exec->create;
  $exec->can_run( [@commands] ); # use a new anon ref, so that we don't have drawbacks if some lower layers will manipulate things.
}

=head2 sudo

Run a single command, a code block, or all commands with C<sudo>. You need perl to be available on the remote systems to use C<sudo>.

Depending on your remote sudo configuration, you may need to define a sudo password with I<sudo_password> first:

 sudo_password 'my_sudo_password'; # hardcoding

Or alternatively, since Rexfile is plain perl, you can read the password from terminal at the start:

 use Term::ReadKey;
 
 print 'I need sudo password: ';
 ReadMode('noecho');
 sudo_password ReadLine(0);
 ReadMode('restore');

Similarly, it is also possible to read it from a secret file, database, etc.

You can turn sudo on globally with:

 sudo TRUE; # run _everything_ with sudo

To run only a specific command with sudo, use :

 say sudo 'id';                # passing a remote command directly
 say sudo { command => 'id' }; # passing anonymous hashref
 
 say sudo { command => 'id', user => 'different' }; # run a single command with sudo as different user
 
 # running a single command with sudo as different user, and `cd` to another directory too
 say sudo { command => 'id', user => 'different', cwd => '/home/different' };

To run multiple commands with C<sudo>, either use an anonymous code reference directly:

 sudo sub {
     service 'nginx' => 'restart';
     say run 'id';
 };

or pass it via C<command> (optionally along a different user):

 sudo {
     command => sub {
         say run 'id';
         say run 'pwd', cwd => '/home/different';
     },
     user => 'different',
 };

B<Note> that some users receive the error C<sudo: sorry, you must have a tty
to run sudo>. In this case you have to disable C<requiretty> for this user.
You can do this in your sudoers file with the following code:

   Defaults:$username !requiretty

=cut

sub sudo {
  my ($cmd) = @_;

  my $options;
  if ( ref $cmd eq "HASH" ) {
    $options = $cmd;
    $cmd     = $options->{command};
  }

  if ( $cmd eq "on" || $cmd eq "-on" || $cmd eq "1" ) {
    Rex::Logger::debug("Turning sudo globally on");
    Rex::global_sudo(1);
    return;
  }
  elsif ( $cmd eq "0" ) {
    Rex::Logger::debug("Turning sudo globally off");
    Rex::global_sudo(0);
    return;
  }

  Rex::get_current_connection_object()->push_use_sudo(1);
  Rex::get_current_connection_object()->push_sudo_options( %{$options} );

  my $ret;

  # if sudo is used with a code block
  if ( ref($cmd) eq "CODE" ) {
    $ret = &$cmd();
  }
  else {
    $ret = i_run( $cmd, fail_ok => 1 );
  }

  Rex::get_current_connection_object()->pop_use_sudo();
  Rex::get_current_connection_object()->pop_sudo_options();

  return $ret;
}

1;
