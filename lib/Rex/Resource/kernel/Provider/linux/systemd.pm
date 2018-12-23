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
use Text::Sprintf::Named qw(named_sprintf);

require Rex::Commands::File;
require Rex::Commands::Fs;
require Rex::Commands::MD5;

extends qw(Rex::Resource::kernel::Provider::linux);
with qw(Rex::Resource::Role::Persistable);

has modules_dir => (
  is => 'ro',
  isa => 'Str',
  default => sub { "/etc/modules-load.d" },
  writer => '_set_modules_dir'
);

has module_template => (
  is => 'ro',
  isa => 'Str',
  default => sub { '%(mod_name)s' },
  writer => '_set_module_template',
);

has module_filename => (
  is => 'ro',
  isa => 'Str',
  default => sub { '%(mod_name)s.conf' },
  writer => '_set_module_filename',
);

sub enabled {
  my ($self) = @_;

  my $changed = $self->present;

  my $mod_name = $self->name;
  my $mod_md5 = md5_hex(named_sprintf($self->module_template, { mod_name => $mod_name }));
  my $remote_md5 = eval { Rex::Commands::MD5::md5($self->modules_dir . "/" . named_sprintf($self->module_filename, { mod_name => $mod_name })); } // "";
  my $exit_code = 0;

  if($mod_md5 eq $remote_md5) {
    # nothing todo
    return $changed;
  }

  my $fs   = Rex::Interface::Fs->create;

  if(! $fs->is_dir( $self->modules_dir )) {
    eval {
      $fs->mkdir( $self->modules_dir );
      $fs->chown( "root", $self->modules_dir );
      $fs->chgrp( "root", $self->modules_dir );
      $fs->chmod( "0700", $self->modules_dir );
    } or do {
      $exit_code = 1;
    };

    if($exit_code) {
      return {
        value => "",
        exit_code => $exit_code,
        changed => 0,
        status => state_failed,
      };
    }
  }

  eval {
    $fs->file_put_contents($self->modules_dir . "/" . named_sprintf($self->module_filename, { mod_name => $mod_name }), named_sprintf($self->module_template, {mod_name => $mod_name}),
      owner => "root",
      group => "root",
      mode  => "0600"
    );
    1;
  } or do {
    $exit_code = 1;
  };

  if($exit_code) {
    return {
      value => "",
      exit_code => $exit_code,
      changed => 0,
      status => state_failed,
    };
  }

  return {
    value => "",
    exit_code => $exit_code,
    changed => 1,
    status => state_changed
  };
}

sub disabled {
  my ($self) = @_;

  my $mod_name = $self->name;
  my $changed = $self->absent;

  my $fs = Rex::Interface::Fs->create;

  if($fs->is_file($self->modules_dir . "/" . named_sprintf($self->module_filename, {mod_name => $mod_name}))) {
    $fs->unlink($self->modules_dir . "/" . named_sprintf($self->module_filename, {mod_name => $mod_name}));

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

  return $fs->is_file($self->modules_dir . "/" . named_sprintf($self->module_filename, {mod_name => $mod_name}));
}

1;
