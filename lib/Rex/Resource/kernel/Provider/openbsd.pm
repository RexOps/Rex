#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::openbsd - Kernel functions for OpenBSD.

=head1 DESCRIPTION

These are the parameters that are supported under OpenBSD.

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

Load the module if it is not loaded and ensure that it is loaded on startup. This option will add a line in **TODO**

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::openbsd;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Data::Dumper;
require Rex::Commands::File;

extends qw(Rex::Resource::kernel::Provider::base);
with qw(Rex::Resource::Role::Ensureable);

sub present {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $entry = "";
  if ( $self->config->{entry} ) {
    $entry = " -e " . $self->config->{entry};
  }

  my $output = i_run "modload $mod_name $entry 2>&1";
  if ( $? != 0 ) {
    die "Error loading module $mod_name:\n$output.";
  }

  $self->_set_status(created);

  return 1;
}

sub absent {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $entry = "";
  if ( $self->config->{entry} ) {
    $entry = " -e " . $self->config->{entry};
  }

  my $output = i_run "modunload $mod_name $entry 2>&1";
  if ( $? != 0 ) {
    die "Error unloading module $mod_name:\n$output.";
  }

  $self->_set_status(removed);

  return 1;
}

sub _list_loaded_modules {
  my ($self) = @_;
  my @loaded;

  #
  # TODO how to list kernel modules in openbsd and netbsd?
  #

  @loaded = i_run "kldstat";
  if ( $? != 0 ) {
    die "Can't list loaded modules.\n" . join( "\n", @loaded );
  }

  chomp @loaded;

  return @loaded;
}

1;
