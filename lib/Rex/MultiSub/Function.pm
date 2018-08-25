#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::MultiSub::Function;

use strict;
use warnings;

# VERSION

use Moose;
use MooseX::Params::Validate;
use Rex::MultiSub::LookupTable;

use Data::Dumper;
use Carp;

extends qw(Rex::MultiSub::PosValidatedList);

has test_wantarray => (
  is      => 'ro',
  isa     => 'Bool',
  default => sub { 0 },
);

override call => sub {
  my ( $self, $code, @args ) = @_;

  my $ret = $code->(@args);

  if (exists $ret->{value}) {
    if ( $self->test_wantarray && wantarray ) {
      return split( /\n/, $ret->{value} );
    }
    else {
      return $ret->{value};
    }
  }

  return undef;
};

1;
