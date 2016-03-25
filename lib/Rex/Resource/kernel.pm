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

use Carp;

resource "kmod", { export => 1 }, sub {
  my $mod_name = resource_name;

  my $mod_config = {
    ensure => param_lookup( "ensure", "present" ),
    name   => $mod_name,
  };

  my $provider =
    param_lookup( "provider",
    get_resource_provider( kernelname(), operating_system() ) );

  Rex::Logger::debug("Get kernel provider: $provider");

  return ( $provider, $mod_config );
};

1;
