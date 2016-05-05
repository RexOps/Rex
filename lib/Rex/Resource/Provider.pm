#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Provider;

use strict;
use warnings;

# VERSION

use Moose;

has __version__ => (
  is      => 'ro',
  isa     => 'Str',
  default => sub { "1" },
);

has name => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has config => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
);

has type => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has status => (
  is      => 'ro',
  isa     => 'Str',
  writer  => '_set_status',
  default => sub { 'unchanged' },
);

1;
