#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Controller::Base;

use strict;
use warnings;

# VERSION

use Moose;

extends qw(Rex::Controller);

has params => (
  is     => 'ro',
  isa    => 'HashRef',
  writer => '_set_params',
);

sub param {
  my ( $self, $what ) = @_;
  return $self->params->{$what} if ($what);
}

sub set_param {
  my ( $self, $what, $value ) = @_;
  my $p = $self->params;
  $p->{$what} = $value;
  $self->_set_params($p);
}

1;
