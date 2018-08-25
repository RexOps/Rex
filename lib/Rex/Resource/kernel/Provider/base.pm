#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::kernel::Provider::base;

use strict;
use warnings;

# VERSION

use Moose;
use Data::Dumper;

use Rex::Helper::Run;

extends qw(Rex::Resource::Provider);

sub test {
  my ($self) = @_;

  my $mod = $self->name;

  my $count = grep { $_ =~ m/^\Q$mod\E\s+/ } $self->_list_loaded_modules;

  if ( $self->config->{ensure} eq "present" && $count ) {
    return 1;
  }
  elsif ( $self->config->{ensure} eq "enabled" && $self->_is_enabled && $count )
  {
    return 1;
  }
  elsif ( $self->config->{ensure} eq "absent" && $count ) {
    return 1;
  }
  elsif ( $self->config->{ensure} eq "disabled"
    && ( $self->_is_enabled || $count ) )
  {
    return 1;
  }

  # we have to do something
  return 0;
}

1;
