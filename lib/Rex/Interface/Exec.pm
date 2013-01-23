#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Exec;
   
use strict;
use warnings;

use Rex;

sub create {
   my ($class, $type) = @_;

   unless($type) {
      $type = Rex::get_current_connection()->{conn}->get_connection_type; #Rex::Commands::task()->get_connection_type;
   }

   my $class_name = "Rex::Interface::Exec::$type";
   eval "use $class_name;";
   if($@) { die("Error loading exec interface $type.\n$@"); }

   return $class_name->new;
}

1;
