#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs;

use strict;
use warnings;

# VERSION

use Rex;
use Data::Dumper;
use Module::Runtime qw(use_module);

sub create {
  my ( $class, $type ) = @_;

  unless ($type) {

    #$type = Rex::Commands::task()->get_connection_type;
    $type = Rex::get_current_connection()->{conn}->get_connection_type;

    #Rex::Commands::task()->get_connection_type;
    #if(Rex::is_ssh() && ! Rex::is_sudo()) {
    #  $type = "SSH";
    #}
    #elsif(Rex::is_sudo()) {
    #  $type = "Sudo";
    #}
    #else {
    #  $type = "Local";
    #}
  }

  my $class_name = "Rex::Interface::Fs::$type";
  eval { use_module( $class_name ) }
      or die("Error loading Fs interface $type.\n$@");

  return $class_name->new;
}

1;
