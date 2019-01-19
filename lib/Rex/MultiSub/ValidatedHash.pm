#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::MultiSub::ValidatedHash;

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

  # some defaults maybe a coderef, so we need to execute this now
  my @_x = @{ $func_opts->{params_list} };
  my %_x = @_x;
  for my $k ( keys %_x ) {
    if ( ref $_x{$k}->{default} eq "CODE" ) {
      $_x{$k}->{default} = $_x{$k}->{default}->(@args);
    }
  }

  my %args = validated_hash(
    \@args, %_x,
    MX_PARAMS_VALIDATE_NO_CACHE    => 1,
    MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1
  );

  return %args;
};

override error => sub {
  my ( $self, @err_msg ) = @_;

  my $name = $self->name;
  croak "Function $name for provided parameter not found.\nErrors:\n"
    . join( "\n", @err_msg );
};

1;
