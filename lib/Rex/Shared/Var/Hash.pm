#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Shared::Var::Hash;

use 5.010001;
use strict;
use warnings;

use Rex::Shared::Var::Common qw/__lock __store __retrieve/;

our $VERSION = '9999.99.99_99'; # VERSION

sub TIEHASH {
  my $self = { varname => $_[1], };
  bless $self, $_[0];
}

sub STORE {
  my $self  = shift;
  my $key   = shift;
  my $value = shift;

  return __lock sub {
    my $ref = __retrieve;
    my $ret = $ref->{ $self->{varname} }->{$key} = $value;
    __store $ref;

    return $ret;
  };
}

sub FETCH {
  my $self = shift;
  my $key  = shift;

  return __lock sub {
    my $ref = __retrieve;
    return $ref->{ $self->{varname} }->{$key};
  };
}

sub DELETE {
  my $self = shift;
  my $key  = shift;

  __lock sub {
    my $ref = __retrieve;
    delete $ref->{ $self->{varname} }->{$key};
    __store $ref;
  };
}

sub CLEAR {
  my $self = shift;

  __lock sub {
    my $ref = __retrieve;
    $ref->{ $self->{varname} } = {};
    __store $ref;
  };
}

sub EXISTS {
  my $self = shift;
  my $key  = shift;

  return __lock sub {
    my $ref = __retrieve;
    return exists $ref->{ $self->{varname} }->{$key};
  };
}

sub FIRSTKEY {
  my $self = shift;

  return __lock sub {
    my $ref = __retrieve;
    $self->{__iter__} = $ref->{ $self->{varname} };

    my $temp = keys %{ $self->{__iter__} };
    return scalar each %{ $self->{__iter__} };
  };
}

sub NEXTKEY {
  my $self    = shift;
  my $prevkey = shift;

  return scalar each %{ $self->{__iter__} };
}

1;
