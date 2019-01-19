#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Role::EnableDisable;

use strict;
use warnings;

# VERSION

use Moose::Role;
use Rex::Resource::Common;

with qw(Rex::Resource::Role::Ensureable);

has ensure_options => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [qw/present absent enable disable/] },
);

requires qw(enable disable);

1;
