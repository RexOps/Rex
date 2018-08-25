#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::run - Execute a command

=head1 DESCRIPTION

With this module it is possible to execute a command on a remote system.

=head1 SYNOPSIS


=cut

package Rex::Resource::run;

use strict;
use warnings;

# VERSION

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;
use Data::Dumper;

use Carp;

# create the resource "kmod"
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
