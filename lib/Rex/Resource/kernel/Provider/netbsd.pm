#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::kernel::Provider::netbsd - Kernel functions for NetBSD.

=head1 DESCRIPTION

These are the parameters that are supported under NetBSD.

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


package Rex::Resource::kernel::Provider::linux::netbsd;

use strict;
use warnings;

# VERSION

use Moose;

extends qw(Rex::Resource::kernel::Provider::openbsd);
with qw(Rex::Resource::Role::Ensureable);

1;
