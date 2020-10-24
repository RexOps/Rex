#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Shared::Var::Scalar;

use 5.010001;
use strict;
use warnings;

use Rex::Shared::Var::Common qw/__lock __store __retrieve/;

our $VERSION = '9999.99.99_99'; # VERSION

sub TIESCALAR {
  my $self = { varname => $_[1], };
  bless $self, $_[0];
}

sub STORE {
  my $self  = shift;
  my $value = shift;

  return __lock sub {
    my $ref = __retrieve;
    my $ret = $ref->{ $self->{varname} } = $value;
    __store $ref;

    return $ret;
  };
}

sub FETCH {
  my $self = shift;

  return __lock sub {
    my $ref = __retrieve;
    return $ref->{ $self->{varname} };
  };
}

1;
