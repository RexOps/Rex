#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec;

use strict;
use warnings;

# VERSION

use Rex;
use Module::Runtime qw(use_module);

sub create {
  my ( $class, $type ) = @_;

  unless ($type) {
    $type = Rex::get_current_connection()->{conn}->get_connection_type;

    #Rex::Commands::task()->get_connection_type;
  }

  my $class_name = "Rex::Interface::Exec::$type";
  eval { use_module( $class_name ) }
      or die("Error loading exec interface $type.\n$@");

  return $class_name->new;
}

1;
