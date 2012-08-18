#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Interface::Executor;

use strict;
use warnings;

use Data::Dumper;

sub create {
   my ($class, $type) = @_;

   unless($type) {
      $type = "Default";
   }

   my $class_name = "Rex::Interface::Executor::$type";
   eval "use $class_name;";
   if($@) { die("Error loading file interface $type.\n$@"); }

   return $class_name->new;

}

1;
