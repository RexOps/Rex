#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Shared::Var::Array;

use 5.010001;
use strict;
use warnings;

use Rex::Shared::Var::Common qw/__lock __store __retrieve/;

our $VERSION = '9999.99.99_99'; # VERSION

sub TIEARRAY {
  my $self = { varname => $_[1], };
  bless $self, $_[0];
}

sub STORE {
  my $self  = shift;
  my $index = shift;
  my $value = shift;

  return __lock sub {
    my $ref = __retrieve;
    my $ret = $ref->{ $self->{varname} }->{data}->[$index] = $value;
    __store $ref;

    return $ret;
  };
}

sub FETCH {
  my $self  = shift;
  my $index = shift;

  return __lock sub {
    my $ref = __retrieve;
    my $ret = $ref->{ $self->{varname} }->{data}->[$index];

    return $ret;
  };
}

sub CLEAR {
  my $self = shift;

  __lock sub {
    my $ref = __retrieve;
    $ref->{ $self->{varname} } = { data => [] };
    __store $ref;
  };
}

sub DELETE {
  my $self  = shift;
  my $index = shift;

  __lock sub {
    my $ref = __retrieve;
    delete $ref->{ $self->{varname} }->{data}->[$index];
    __store $ref;
  };
}

sub EXISTS {
  my $self  = shift;
  my $index = shift;

  return __lock sub {
    my $ref = __retrieve;
    return exists $ref->{ $self->{varname} }->{data}->[$index];
  };
}

sub PUSH {
  my $self = shift;
  my @data = @_;

  __lock sub {
    my $ref = __retrieve;

    if ( !ref( $ref->{ $self->{varname} }->{data} ) eq "ARRAY" ) {
      $ref->{ $self->{varname} }->{data} = [];
    }

    push( @{ $ref->{ $self->{varname} }->{data} }, @data );

    __store $ref;
  };
}

sub UNSHIFT {
  my $self = shift;
  my @data = @_;

  __lock sub {
    my $ref = __retrieve;

    if ( !ref( $ref->{ $self->{varname} }->{data} ) eq "ARRAY" ) {
      $ref->{ $self->{varname} }->{data} = [];
    }

    unshift( @{ $ref->{ $self->{varname} }->{data} }, @data );

    __store $ref;
  };
}

sub SHIFT {
  my $self = shift;
  my @data = @_;
  my $result;

  __lock sub {
    my $ref = __retrieve;

    $result = shift( @{ $ref->{ $self->{varname} }->{data} } );

    __store $ref;
  };

  return $result;
}

sub POP {
  my $self = shift;
  my @data = @_;
  my $result;

  __lock sub {
    my $ref = __retrieve;

    $result = pop( @{ $ref->{ $self->{varname} }->{data} } );

    __store $ref;
  };

  return $result;
}

sub EXTEND {
  my $self  = shift;
  my $count = shift;
}

sub STORESIZE {
  my $self    = shift;
  my $newsize = shift;
}

sub FETCHSIZE {
  my $self = shift;

  return __lock sub {
    my $ref = __retrieve;
    if ( !exists $ref->{ $self->{varname} } ) {
      return 0;
    }
    return scalar( @{ $ref->{ $self->{varname} }->{data} } );
  };
}

1;
