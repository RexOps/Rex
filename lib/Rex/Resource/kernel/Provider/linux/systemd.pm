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
use Digest::MD5 qw(md5_hex);

require Rex::Commands::File;
require Rex::Commands::Fs;
require Rex::Commands::MD5;

extends qw(Rex::Resource::kernel::Provider::linux);
with qw(Rex::Resource::Role::Persistable);

sub enabled {
  my ($self) = @_;

  my $changed = $self->present;

  my $mod_name = $self->name;
  my $mod_md5 = md5_hex($mod_name);
  my $remote_md5 = eval { Rex::Commands::MD5::md5("/etc/modules-load.d/$mod_name.conf"); } // "";

  if($mod_md5 eq $remote_md5) {
    # nothing todo
    return $changed;
  }

  my $fs   = Rex::Interface::Fs->create;

  if(! $fs->is_dir( "/etc/modules-load.d" )) {
    $fs->mkdir( "/etc/modules-load.d" );
    $fs->chown( "root", "/etc/modules-load.d" );
    $fs->chgrp( "root", "/etc/modules-load.d" );
    $fs->chmod( "0700", "/etc/modules-load.d" );
  }

  $fs->file_put_contents("/etc/modules-load.d/$mod_name.conf", $mod_name,
    owner => "root",
    group => "root",
    mode  => "0600"
  );

  return {
    value => "",
    exit_code => 0,
    changed => 1,
    status => state_changed
  };
}

sub disabled {
  my ($self) = @_;

  my $mod_name = $self->name;
  my $changed = $self->absent;

  my $fs = Rex::Interface::Fs->create;

  if($fs->is_file("/etc/modules-load.d/$mod_name.conf")) {
    $fs->unlink("/etc/modules-load.d/$mod_name.conf");

    return {
      value => "",
      exit_code => 0,
      changed => 1,
      status => state_changed
    };
  }
  else {
    return $changed;
  }

  return {
    value => "",
    exit_code => 0,
    changed => 1,
    status => state_changed
  };
}

sub _is_enabled {
  my ($self) = @_;

  my $mod_name = $self->name;
  my $fs       = Rex::Interface::Fs->create;

  return $fs->is_file("/etc/modules-load.d/$mod_name.conf");
}

1;
