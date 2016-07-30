#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel - Kernel functions

=head1 DESCRIPTION

With this module it is possible to manage system kernel like loading/unloading of modules.

=head1 SYNOPSIS

 # Load a kernel module
 task "configure_kernel", "server01", sub {
   kmod "module-name",
     entry  => "foo",
     ensure => "present";

   kmod "module-name",
     ensure   => "present",
     provider => "linux";
 };

=cut

package Rex::Resource::kernel;

use strict;
use warnings;

# VERSION

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;
use Data::Dumper;

use Carp;

# create the resource "kmod"
resource "kmod", {

  # export this resource to the main namespace. so that it can be used
  # directly in Rexfile without the need to prepend the namespace of the module.
  export => 1,

  # define the parameter this resource will have
  # rex is doing a type check here.
  params_list => [
    mod => {
      isa => 'Str',

      # default is the name parameter (kmod $name, ensure => "present";)
      default => sub { shift }
    },
    ensure => {
      isa     => 'Str',
      default => sub { "present" }
    },
  ],
  },
  sub {
  my ($c) = @_;

  # here we define the provider the resource should use. If someone want to use
  # a custom provider we will use this. Otherwise we try to detect the provider
  # automatically.
  my $provider = $c->param("provider")
    || get_resource_provider( kernelname(), operating_system() );

  Rex::Logger::debug("Get kernel provider: $provider");

  # at the end we return the wanted provider and an hash reference containing
  # all the parameters for this resource.
  # here we just pass the parameters back without modifying them.
  return ( $provider, $c->params );
  };

1;
