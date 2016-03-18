#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::Role::Ensureable;

use strict;
use warnings;

# VERSION

use Moo::Role;
use List::Util qw(first);
use Rex::Resource::Common;

requires qw(present absent);

has ensure_options => (
  is      => 'ro',
  default => sub {[qw/present absent/]},
);

sub process {
  my ($self, $mod_config, $res_type, $res_name) = @_;
  
  my $okay = first { $_ eq $mod_config->{ensure} } @{ $self->ensure_options };
  
  if(! $okay) {
    die "Error: $mod_config->{ensure} not a valid option for 'ensure'.";
  }
  
  if ( $self->$okay($mod_config) ) {
    emit created, "$res_type" . "[$res_name] is now $okay.";
  }

}

1;