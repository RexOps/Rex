#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::MultiSub::Resource;

use strict;
use warnings;

# VERSION

use Moose;
use MooseX::Params::Validate;
use Rex::MultiSub::LookupTable;

use Data::Dumper;
use Carp;
use Clone qw(clone);

extends qw(Rex::MultiSub::ValidatedHash);

override validate => sub {
  my ( $self, $func_opts, @args ) = @_;
  my @modified_args = @args;
  my $name          = shift @modified_args;

  # some defaults maybe a coderef, so we need to execute this now
  my @_x = @{ clone($func_opts->{params_list}) };
  my %_x = @_x;
  for my $k ( keys %_x ) {
    if ( ref $_x{$k}->{default} eq "CODE" ) {
      $_x{$k}->{default} = $_x{$k}->{default}->(@args);
    }
  }
  my %args = validated_hash(
    \@modified_args, %_x,
    MX_PARAMS_VALIDATE_NO_CACHE    => 1,
    MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1
  );

  return ( $args[0], %args );
};

override call => sub {
  my ( $self, $code, @args ) = @_;

  # TODO check for common parameters like
  # * timeout
  # * only_notified
  # * only_if
  # * unless
  # * creates
  # * on_change
  # * on_before_change
  # * ensure

  # TODO migrate reporting and error handling from Rex::Resource
  # TODO remove Rex::Resource class
  # TODO add default values for $args[1] if $args[0] is hash

  if ( ref $args[0] eq "HASH" ) {
    for my $k_name ( keys %{ $args[0] } ) {
      $code->( $k_name, %{ $args[0]->{$k_name} } );
    }
  }
  elsif ( ref $args[0] eq "ARRAY" ) {
    for my $v_name ( @{ $args[0] } ) {
      $code->( $v_name, @args[ 1 .. $#args ] );
    }
  }
  else {
    my $ret = $code->(@args);
    if(wantarray) {
      return split(/\n/, $ret->{value});
    }
    return $ret->{value};
  }
};

1;
