#
# (c) Nathan Abu <aloha2004@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Output::Base;

use strict;
use warnings;

# VERSION

use Moose;

extends qw(Rex::Output);

sub print_s {
  my ($self, $data) = @_;
  print "[$data->{title}] $data->{msg} ";
}

sub endln_ok {
  my ($self) = @_;
  print "done.\n";
}

sub endln_failed {
  my ($self) = @_;
  print "failed.\n";
}

1;
