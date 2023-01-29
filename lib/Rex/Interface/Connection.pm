#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::Connection;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub create {
  my ( $class, $type ) = @_;

  unless ($type) {
    $type = Rex::Config->get_connection_type();
  }

  my $class_name = "Rex::Interface::Connection::$type";
  eval "use $class_name;";
  if ($@) { die("Error loading connection interface $type.\n$@"); }

  return $class_name->new;
}

1;
