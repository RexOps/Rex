#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux::systemd - Kernel functions for systemd systems.

=head1 DESCRIPTION

These are the parameters that are supported under systemd systems. This is a base class for distributions using systemd.

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

=item enabled

Load the module if it is not loaded and ensure that it is loaded on startup. This option will add a file to I</etc/modules-load.d/>.

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::linux::systemd;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Rex::Commands::Gather;
use Data::Dumper;
require Rex::Commands::File;
require Rex::Commands::Fs;

extends qw(Rex::Resource::kernel::Provider::linux);
with qw(Rex::Resource::Role::Persistable);

sub enabled {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $changed = $self->present;
  my $os_ver  = operating_system_release();

  Rex::Commands::File::file(
    "/etc/modules-load.d/$mod_name.conf",
    ensure    => "present",
    content   => $mod_name,
    user      => "root",
    group     => "root",
    mode      => "0600",
    on_change => sub { $changed = 1; },
  );

  $self->_set_status(created);

  return $changed;
}

sub disabled {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $changed = $self->absent;
  my $os_ver  = operating_system_release();

  Rex::Commands::File::file(
    "/etc/modules-load.d/$mod_name.conf",
    ensure    => "absent",
    on_change => sub { $changed = 1; },
  );

  $self->_set_status(removed);

  return $changed;
}

sub _is_enabled {
  my ($self) = @_;

  my $mod_name = $self->name;

  return Rex::Commands::Fs::is_file("/etc/modules-load.d/$mod_name.conf");
}

1;
