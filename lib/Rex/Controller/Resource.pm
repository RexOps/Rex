#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Controller::Resource;

use strict;
use warnings;

# VERSION

use Moose;

extends qw(Rex::Controller);

has params => (
  is  => 'ro',
  isa => 'HashRef'
);

sub param {
  my ( $self, $what ) = @_;
  return $self->params->{$what} if ($what);
}

1;
