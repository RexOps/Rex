#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux::debian_legacy - Kernel functions for legacy Debian GNU/Linux.

=head1 DESCRIPTION

These are the parameters that are supported under Debian GNU/Linux.

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

Load the module if it is not loaded and ensure that it is loaded on startup. This option will add line to I</etc/modules>. 

If the system has systemd it will add a file to I</etc/modules-load.d/>.

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::linux::debian_legacy;

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
  my ( $self ) = @_;

  my $mod_name = $self->name;

  my $changed = $self->present;

  my $fs = Rex::Interface::Fs->create;

  my $my_changed = 0;
  my $exit_code = 0;

  if($fs->is_file("/etc/modules")) {
    eval {
      Rex::Commands::File::append_if_no_such_line( "/etc/modules", $mod_name,
        on_change => sub { $my_changed = 1; } );
      1;
    } or do {
      $exit_code = 1;
    };
  }
  else {
    eval {
      $fs->file_put_contents("/etc/modules", "$mod_name\n",
        owner => "root",
        group => "root",
        mode  => "0644",
      );

      $my_changed = 1;
      $exit_code = 0;
      1;
    } or do {
      $exit_code = 1;
    };
  }

  return {
    value => "",
    exit_code => $exit_code,
    changed => ($my_changed || $changed->{changed}),
    status => ($my_changed ? state_changed : $changed->{status}),
  };
}

sub disabled {
  my ( $self ) = @_;

  my $mod_name = $self->name;

  my $changed = $self->absent;
  my $my_changed = 0;
  my $exit_code = 0;

  my $fs = Rex::Interface::Fs->create;

  if($fs->is_file("/etc/modules")) {
    eval {
      Rex::Commands::File::delete_lines_according_to( qr{^\Q$mod_name\E$},
        "/etc/modules", on_change => sub { $my_changed = 1; } );
      1;
    } or do {
      $exit_code = 1;
    };
  }

  return {
    value => "",
    exit_code => $exit_code,
    changed => ($my_changed || $changed->{changed}),
    status => ($my_changed ? state_changed : $changed->{status}),
  };
};

sub _is_enabled {
  my ( $self ) = @_;

  my $mod_name = $self->name;

  my ($enabled) = grep { m/^\Q$mod_name\E$/ } i_run "cat /etc/modules";
  return $enabled;
};

1;
