#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::MultiSub::PosValidatedList;

use strict;
use warnings;

# VERSION

use Moose;
use MooseX::Params::Validate;
use Rex::MultiSub::LookupTable;

use Data::Dumper;
use Carp;

extends qw(Rex::MultiSub);

override validate => sub {
  my ( $self, $func_opts, @args ) = @_;

  my @_x = @{ $func_opts->{params_list} };
  my @order = map { $_x[$_] } grep { $_ & 1 } 1 .. $#_x;

  my @v_args = pos_validated_list(
    \@args, @order,
    MX_PARAMS_VALIDATE_NO_CACHE    => 1,
    MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1
  );

  return @v_args;
};

override error => sub {
  my ( $self, @err_msg ) = @_;

  my $name = $self->name;
  croak "Function $name for provided parameter not found.\nErrors:\n"
    . join( "\n", @err_msg );
};

1;

