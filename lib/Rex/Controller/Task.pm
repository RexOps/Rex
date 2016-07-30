#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Controller::Task;

use strict;
use warnings;

# VERSION

use Moose;

extends qw(Rex::Controller::Base);

has task => (
  is  => 'ro',
  isa => 'Rex::Task',
);

1;
