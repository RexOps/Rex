#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::pkg;

use strict;
use warnings;

# VERSION

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;
use Data::Dumper;

use Carp;

# create the resource "pkg"
resource "pkg", {

  # export this resource to the main namespace. so that it can be used
  # directly in Rexfile without the need to prepend the namespace of the module.
  export => 1,

  # define the parameter this resource will have
  # rex is doing a type check here.
  params_list => [
    "package" => {
      isa => 'Str | ArrayRef[Str]',

      # default is the name parameter (file $name;)
      default => sub { shift }
    },
    ensure       => { isa => 'Str', default => sub { "present" }},
  ],
  },
  sub {
  my ( $name, %args ) = @_;

  # here we define the provider the resource should use. If someone want to use
  # a custom provider we will use this. Otherwise we try to detect the provider
  # automatically.
  my $provider = resolve_resource_provider($args{provider}
    || get_resource_provider( kernelname(), operating_system() ));

  # TODO define provider type automatically.
  $provider->require;

  Rex::Logger::debug("Get pkg provider: $provider");

  my $provider_o =
    $provider->new( type => "pkg", name => $name, config => { %args } );
  $provider_o->process;
  };

1;

=head1 NAME

Rex::Resource::pkg - Ensures the state of a package on the remote system.

=head1 DESCRIPTION

With the pkg() resource it is possible to manage packages on the remote system.

=head1 SYNOPSIS

 task "configure_something", "server01", sub {
 };

=head2 run $command, %options

Supported options are:

  package           => $package
    sets the package that should be installed or removed. if not present, use the resource name.

=cut
