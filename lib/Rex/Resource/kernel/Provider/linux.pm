#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux - Kernel functions for Linux.

=head1 DESCRIPTION

These are the parameters that are supported under FreeBSD.

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

package Rex::Resource::kernel::Provider::linux;

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

  my $output = i_run "modprobe -v $mod_name 2>&1", fail_ok => 1;

  return {
    value => $output,
    exit_code => $?,
    changed => 1,
    status => changed
  };
}

sub absent {
  my ($self) = @_;

  my $mod_name = $self->name;

  my $output = i_run "rmmod $mod_name 2>&1", fail_ok => 1;

  return {
    value => $output,
    exit_code => $?,
    changed => 1,
    status => removed
  };
}

sub _list_loaded_modules {
  my ($self) = @_;
  my @loaded;

  @loaded = i_run "lsmod";
  if ( $? != 0 ) {
    die "Can't list loaded modules.\n" . join( "\n", @loaded );
  }

  chomp @loaded;

  return @loaded;
}

1;
