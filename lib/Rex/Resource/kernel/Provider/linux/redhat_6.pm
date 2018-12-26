#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::linux::redhat_6 - Kernel functions for Redhat 6 Linux and clones.

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

On Redhat 6 it will add a file into I</etc/sysconfig/modules/>.

=item disabled.

Unload the module if module is loaded and ensure that the module isn't loaded on startup.

=back

=back

=cut

package Rex::Resource::kernel::Provider::linux::redhat_6;

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

sub BUILD {
  my ($self) = @_;
  super();
  $self->_set_modules_dir("/etc/sysconfig/modules");
  $self->_set_module_template("#!/bin/sh\nexec /sbin/modprobe \%(mod_name)s");
  $self->_set_module_filename("\%(mod_name)s.modules");
}

1;