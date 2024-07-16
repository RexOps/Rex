#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::Fs;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex;
use Data::Dumper;

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
  eval "use $class_name;";
  if ($@) { die("Error loading Fs interface $type.\n$@"); }

  return $class_name->new;
}

1;
