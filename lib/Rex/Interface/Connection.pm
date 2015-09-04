#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Connection;

use strict;
use warnings;

# VERSION

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
