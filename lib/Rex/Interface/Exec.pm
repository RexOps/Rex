#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Interface::Exec;

use warnings;

use Rex;

sub create {
  my ( $class, $type ) = @_;

  unless ($type) {
    $type = Rex::get_current_connection()->{conn}
      ->get_connection_type;    #Rex::Commands::task()->get_connection_type;
  }

  my $class_name = "Rex::Interface::Exec::$type";
  eval "use $class_name;";
  if ($@) { die("Error loading exec interface $type.\n$@"); }

  return $class_name->new;
}

1;
