#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
#
# this is a simple helper class for the get() function

use strict;

package Rex::Value;

use warnings;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub value {
  my ($self) = @_;
  return $self->{value};
}

1;
