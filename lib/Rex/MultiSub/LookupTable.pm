#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::MultiSub::LookupTable;

use strict;
use warnings;

# VERSION

use MooseX::Singleton;

has data => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} },
);

sub add {
  my ( $self, $name, $params_list, $code ) = @_;
  push @{ $self->data->{$name} },
    {
    params_list => $params_list,
    code        => $code,
    };
}

1;
