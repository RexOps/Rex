#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hook;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

=head1 NAME

Rex::Hook - manage Rex hooks

=head1 DESCRIPTION

This module manages hooks of various Rex functions.

=head1 SYNOPSIS

 use Rex::Hook;
 
 register_function_hooks { $state => { $function => $coderef, }, };

=cut

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(register_function_hooks);

my $__hooks = {};

=head1 EXPORTED FUNCTIONS

=head2 register_function_hooks { $state => { $function => $coderef } };

Registers a C<$coderef> to be called when C<$function> reaches C<$state> during its execution.

For example:

 register_function_hooks { before_change => { file => \&backup } };

C<$coderef> may get parameters passed to it depending on the hook in question. See the given hook's documentation about details.

=cut

sub register_function_hooks {
  my ($hooks) = @_;

  for my $state ( keys %{$hooks} ) {
    for my $func ( keys %{ $hooks->{$state} } ) {
      if ( !exists $__hooks->{$state}->{$func} ) {
        $__hooks->{$state}->{$func} = [];
      }

      push @{ $__hooks->{$state}->{$func} }, $hooks->{$state}->{$func};
    }
  }
}

sub run_hook {
  my ( $command, $state, @args ) = @_;

  if ( !exists $__hooks->{$state}->{$command} ) {
    return;
  }

  my $func_arr = $__hooks->{$state}->{$command};

  for my $func ( @{$func_arr} ) {
    @args = $func->(@args);
  }

  return @args;
}

1;
