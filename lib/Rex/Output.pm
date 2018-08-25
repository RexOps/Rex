#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Output;

use strict;
use warnings;

# VERSION

use Moose;

sub create {
  my ( $class, $type ) = @_;

  $type ||= "Rex::Output::Base";

  $type->require;

  my $c = $type->new;
  return $c;
}

sub stash {
  my ( $self, $key, $value ) = @_;
  $self->{__data__}->{$key} = $value;
}

1;
