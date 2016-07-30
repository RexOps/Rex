#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Function::run;

use strict;
use warnings;

# VERSION

use Rex -minimal;
use Rex::Function::Common;
use Rex::Helper::Path;

# define run() function
# the run() function has 2 prototypes with different parameters
# here we can define both and also define which parameters each prototype has
# so that the code in Rex::Function::Common can detect the right code.

function "run", {

  # export this function to the main namespace. so that it can be used
  # directly in Rexfile without the need to prepend the namespace of the module.
  export => 1,

  # define the parameter this function will have
  # rex is doing a type check here.
  # the keyname is yet without any meaning. but can be used for automatic
  # document generation or other things later.
  params_list => [

    # this code block is responsible for run calls with only one string
    # parameter.
    # for example: run "ls -l";
    # You can use the types that are known by Moose here.
    command => { isa => 'Str' },
  ],
  },
  sub {
  _run_command(@_);
  };

# create a second definition for the run() function
function "run", {

  # we also export this to the main namespace. as long as one definition export
  # itself to the namespace, all other definitions of this function will also
  # gets exported, regardles what is set here.
  export => 1,

  # this code block is responsible to execute if 2 parameters are given.
  # the first parameter must be a string (Str) and the second parameter
  # must be an array reference (ArrayRef)
  # You can use the types that are known by Moose here.
  params_list => [
    command   => { isa => 'Str' },
    arguments => { isa => 'ArrayRef' },
  ],
  },
  sub {
  _run_command(@_);
  };

sub _run_command {
  my $app = shift;
  my $cmd = shift;
  my ( $args, $options, $path );

  if ( ref $_[0] eq "ARRAY" ) {
    $args = shift;
  }
  else {
    $args = [];
  }

  $options = {@_} if @_;

  my $exec = Rex::Interface::Exec->create;

  if ( !Rex::Config->get_no_path_cleanup() ) {
    $path = join( ":", Rex::Config->get_path() );
  }

  if ( scalar @{$args} ) {
    my $quoter = Net::OpenSSH::ShellQuoter->quoter( $exec->shell->name );
    $cmd = "$cmd " . join( " ", map { $quoter->quote($_) } @{$args} );
  }

  my ( $out, $err ) = $exec->exec( $cmd, $path, $options );

  chomp $out if $out;
  chomp $err if $err;

  if ( !defined $out ) {
    $out = "";
  }

  if ( !defined $err ) {
    $err = "";
  }

  if ( $? == 127 ) {
    $app->output->stash( error_info => "Command not found.", error_code => $? );
  }
  elsif ( $? != 0 ) {
    $app->output->stash( error_info => "Return code: $?", error_code => $? );
  }

  my $ret = {};
  $ret->{value} = $out;

  return $ret;
}

1;

=head1 NAME

Rex::Function::run - Execute a command

=head1 DESCRIPTION

With the run() function you can execute a command.

=head1 SYNOPSIS

 task "configure_something", "server01", sub {
   my $lines = run "something";
   if( $? != 0 ) {
     say "Something went wrong.";
   }
 };

=head1 EXPORTED FUNCTIONS

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

  cwd           => $path
    sets the working directory of the executed command to $path
  only_if       => $condition_command
    executes the command only if $condition_command completes successfully
  unless        => $condition_command
    executes the command unless $condition_command completes successfully
  only_notified => TRUE
    queues the command, to be executed upon notification (see below)
  env           => { var1 => $value1, ..., varN => $valueN }
    sets environment variables in the environment of the command
  timeout       => value
    sets the timeout for the command to be run
  auto_die      => TRUE
    die if the command returns with a non-zero exit code
    it can be set globally via the exec_autodie feature flag
  command       => $command_to_run
    if set, run tries to execute the specified command and the first argument
    becomes an identifier for the run block (e.g. to be triggered with notify)
  creates       => $file_to_create
    tries to create $file_to_create upon execution
    skips execution if the file already exists

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
