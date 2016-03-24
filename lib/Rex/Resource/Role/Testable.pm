#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Role::Testable;

use strict;
use warnings;

# VERSION

use Moose::Role;

requires qw(test);

1;
