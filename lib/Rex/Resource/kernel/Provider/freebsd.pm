#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::freebsd - Kernel functions for FreeBSD

=head1 DESCRIPTION

These are the parameters that are supported under FreeBSD.

=head1 PARAMETER

=over 4

=item entry 

Entrypoint for module loading.

=item ensure

What state the resource should be ensured. 

Valid options:

=over 4

=item present

Load the module if it is not loaded.

=item absent

Unload the module if module is loaded.

=item enabled

Load the module if it is not loaded and ensure that it is loaded on startup. This option will add a line in I</boot/loader.conf>.

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::freebsd;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Data::Dumper;
require Rex::Commands::File;

extends qw(Rex::Resource::kernel::Provider::base);
with qw(Rex::Resource::Role::Persistable);

sub present {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $output = i_run "kldload $mod_name 2>&1";
  if ( $? != 0 ) {
    die "Error loading module $mod_name:\n$output.";
  }

  $self->_set_status(created);

  return 1;
}

sub absent {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $output = i_run "kldunload $mod_name 2>&1";
  if ( $? != 0 ) {
    die "Error unloading module $mod_name:\n$output.";
  }

  $self->_set_status(removed);

  return 1;
}

sub enabled {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $changed = $self->present;

  Rex::Commands::File::append_if_no_such_line( "/boot/loader.conf",
    "${mod_name}_load=\"YES\"", on_change => sub { $changed = 1; } );

  $self->_set_status(created);

  return $changed;
}

sub disabled {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $changed = $self->absent;

  Rex::Commands::File::delete_lines_according_to(
    qr{^\Q$mod_name\E_load="YES"$},
    "/boot/loader.conf", on_change => sub { $changed = 1; } );

  $self->_set_status(removed);

  return $changed;
}

sub _list_loaded_modules {
  my ($self) = @_;
  my @loaded;

  @loaded = i_run "kldstat";
  if ( $? != 0 ) {
    die "Can't list loaded modules.\n" . join( "\n", @loaded );
  }

  chomp @loaded;

  return @loaded;
}

1;
