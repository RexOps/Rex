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

  my $res_available = $self->test;

  if ( ( $ensure_func eq "present" && !$res_available )
    || ( $ensure_func eq "absent"  && $res_available )
    || ( $ensure_func ne "present" && $ensure_func ne "absent" ) )
  {
    return $self->execute_resource_code($ensure_func);
  }
}

1;
