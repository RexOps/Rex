#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::run;

use strict;
use warnings;

# VERSION

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;
use Data::Dumper;

use Carp;

# create the resource "run"
resource "run", {

  # export this resource to the main namespace. so that it can be used
  # directly in Rexfile without the need to prepend the namespace of the module.
  export => 1,

  # define the parameter this resource will have
  # rex is doing a type check here.
  params_list => [
    command => {
      isa => 'Str',

      # default is the name parameter (run $name;)
      default => sub { shift }
    },
    path => { isa => 'Str | ArrayRef[Str] | Undef', default => undef },
    env  => { isa => 'HashRef | Undef', default => undef },
  ],
  },
  sub {
  my ( $name, %args ) = @_;

  # here we define the provider the resource should use. If someone want to use
  # a custom provider we will use this. Otherwise we try to detect the provider
  # automatically.
  my $provider = $args{provider}
    || "Rex::Resource::run::Provider::POSIX";

  # TODO define provider type automatically.
  $provider->require;

  Rex::Logger::debug("Get kernel provider: $provider");

  my $provider_o =
    $provider->new( type => "run", name => $name, config => { %args } );
  $provider_o->process;
  };

1;

=head1 NAME

Rex::Resource::run - Execute a command on a system

=head1 DESCRIPTION

With the run() resource you can ensure the a given command gets executed on a remote system.

=head1 SYNOPSIS

 task "configure_something", "server01", sub {
   my $lines = run "something";
   if( $? != 0 ) {
     say "Something went wrong.";
   }
 };

=head2 run $command, %options

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

=cut
