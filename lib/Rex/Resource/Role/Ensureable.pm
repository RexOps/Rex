#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Role::Ensureable;

use strict;
use warnings;

# VERSION

use Moose::Role;
use List::Util qw(first);
use Rex::Resource::Common;

with qw(Rex::Resource::Role::Testable);

has ensure_options => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [qw/present absent/] },
);

requires qw(present absent);

sub process {
  my ($self) = @_;

  my $ensure_func =
    first { $_ eq $self->config->{ensure} } @{ $self->ensure_options };

  if ( !$ensure_func ) {
    die "Error: "
      . $self->config->{ensure}
      . " not a valid option for 'ensure'.";
  }

  if ( !$self->test ) {
    #### check and run before_change hook
    Rex::Hook::run_hook(
      $self->type => "before_change",
      $self->name, %{ $self->config }
    );
    ##############################

    $self->$ensure_func;

    #### check and run after_change hook
    Rex::Hook::run_hook(
      $self->type => "after_change",
      $self->name, %{ $self->config }
    );
    ##############################
  }
}

1;
