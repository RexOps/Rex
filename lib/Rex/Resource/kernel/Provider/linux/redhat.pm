#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux::redhat - Kernel functions for Redhat Linux and clones.

=head1 DESCRIPTION

These are the parameters that are supported under Redhat Linux and clones.

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

Load the module if it is not loaded and ensure that it is loaded on startup. 

On Redhat 4 and 5 it will add line to I</etc/rc.modules>. 

On Redhat 6 it will add a file into I</etc/sysconfig/modules/>.

If the system has systemd it will add a file to I</etc/modules-load.d/>.

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::linux::redhat;

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

extends qw(Rex::Resource::kernel::Provider::linux::systemd);
with qw(Rex::Resource::Role::Persistable);

around enabled => sub {
  my ( $orig, $self ) = @_;

  my $mod_name = $self->name;

  my $changed = $self->present;
  my $os_ver  = operating_system_release();

  if ( $os_ver =~ m/^[45]/ ) {
    Rex::Commands::File::append_if_no_such_line( "/etc/rc.modules", $mod_name,
      on_change => sub { $changed = 1; } );

    $self->_set_status(created);
  }
  elsif ( $os_ver =~ m/^6/ ) {
    Rex::Commands::File::file(
      "/etc/sysconfig/modules/$mod_name.modules",
      ensure    => "present",
      content   => "#!/bin/sh\nexec /sbin/modprobe $mod_name",
      user      => "root",
      group     => "root",
      mode      => "0700",
      on_change => sub { $changed = 1; },
    );

    $self->_set_status(created);
  }
  else {
    $changed = $self->$orig();
  }

  return $changed;
};

around disabled => sub {
  my ( $orig, $self ) = @_;

  my $mod_name = $self->name;

  my $changed = $self->present;
  my $os_ver  = operating_system_release();

  if ( $os_ver =~ m/^[45]/ ) {
    Rex::Commands::File::delete_lines_according_to( qr{^\Q$mod_name\E$},
      "/etc/rc.modules", on_change => sub { $changed = 1; } );

    $self->_set_status(removed);
  }
  elsif ( $os_ver =~ m/^6/ ) {
    Rex::Commands::File::file(
      "/etc/sysconfig/modules/$mod_name.modules",
      ensure    => "absent",
      on_change => sub { $changed = 1; },
    );

    $self->_set_status(removed);
  }
  else {
    $changed = $self->$orig();
  }

  return $changed;
};

around _is_enabled => sub {
  my ( $orig, $self ) = @_;

  my $mod_name = $self->name;
  my $os_ver   = operating_system_release();

  if ( $os_ver =~ m/^[45]/ ) {
    my ($enabled) = grep { m/^\Q$mod_name\E$/ } i_run "cat /etc/rc.modules";
    return $enabled;
  }
  elsif ( $os_ver =~ m/^6/ ) {
    return Rex::Commands::Fs::is_file(
      "/etc/sysconfig/modules/$mod_name.modules");
  }
  else {
    return $self->$orig();
  }

};

1;
