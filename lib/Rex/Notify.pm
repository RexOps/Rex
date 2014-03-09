#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Notify;

use strict;
use warnings;

sub new {
  my $that = shift;
  my $proto = ref($that) || $that;
  my $self = { @_ };

  bless($self, $proto);

  $self->{__types__} = {};

  return $self;
}

sub add {
  my ($self, %option) = @_;

  if(exists $self->{__types__}->{$option{type}}->{$option{name}}) {
    die("A resource of the type $option{type} and name $option{name} already exists.");
  }

  $self->{__types__}->{$option{type}}->{$option{name}} = {
    options => $option{options},
    cb    => $option{cb},
  };
}

sub run {
  my ($self, %option) = @_;

  my $cb = $self->{__types__}->{$option{type}}->{$option{name}}->{cb};
  $cb->($self->{__types__}->{$option{type}}->{$option{name}}->{options});
}

1;
