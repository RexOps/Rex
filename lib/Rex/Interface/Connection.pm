#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection;
   
use strict;
use warnings;

sub create {
   my ($class, $type) = @_;

   unless($type) {
      $type = "SSH";
   }

   my $class_name = "Rex::Interface::Connection::$type";
   eval "use $class_name;";
   if($@) { die("Error loading connection interface $type.\n$@"); }

   return $class_name->new;
}

1;
