#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux::openwrt - Kernel functions for OpenWrt Linux.

=head1 DESCRIPTION

These are the parameters that are supported under OpenWrt Linux.

=head1 PARAMETER

=over 4

=item ensure

What state the resource should be ensured. 

Valid options:

=over 4

=item present

Load the module if it is not loaded.

=item absent

Unload the module if module is loaded.

=back

=back

=cut

package Rex::Resource::kernel::Provider::linux::openwrt;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Data::Dumper;
require Rex::Commands::File;

extends qw(Rex::Resource::kernel::Provider::linux);
with qw(Rex::Resource::Role::Ensureable);

override present => sub {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $output = i_run "insmod $mod_name 2>&1";
  if ( $? != 0 ) {
    die "Error loading module $mod_name:\n$output.";
  }

  $self->_set_status(created);

  return 1;
};

override absent => sub {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $output = i_run "rmmod $mod_name 2>&1";
  if ( $? != 0 ) {
    die "Error unloading module $mod_name:\n$output.";
  }

  $self->_set_status(removed);

  return 1;
};

1;
