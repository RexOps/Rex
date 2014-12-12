#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hook;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(register_function_hooks);

my $__hooks = {};

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
