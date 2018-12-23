#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux::gentoo_confd - Kernel functions for Gentoo Linux.

=head1 DESCRIPTION

These are the parameters that are supported under Gentoo Linux.

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

Load the module if it is not loaded and ensure that it is loaded on startup. This option will add line to I</etc/conf.d/modules>. 

If the system has systemd it will add a file to I</etc/modules-load.d/>.

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::linux::gentoo_confd;

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

extends qw(Rex::Resource::kernel::Provider::linux::debian_legacy);
with qw(Rex::Resource::Role::Persistable);

sub BUILD {
  my ($self) = @_;
  $self->_set_modules_file("/etc/conf.d/modules");
}

1;
