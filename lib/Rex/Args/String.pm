#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Args::String;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub get {
  my ( $class, $name ) = @_;

  my $arg = shift @ARGV;
  return $arg;
}

1;
