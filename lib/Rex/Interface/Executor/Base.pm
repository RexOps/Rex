#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Executor::Base;

use strict;
use warnings;

# VERSION

use Moose;

has app => (
  is  => 'ro',
  isa => 'Rex',
);

has task => (
  is  => 'ro',
  isa => 'Rex::Task'
);

sub set_task {
  my ( $self, $task ) = @_;
  $self->{task} = $task;
}

1;
