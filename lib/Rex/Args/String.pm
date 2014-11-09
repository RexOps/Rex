#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Args::String;

use warnings;

sub get {
  my ( $class, $name ) = @_;

  my $arg = shift @ARGV;
  return $arg;
}

1;
