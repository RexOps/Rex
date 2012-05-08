#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Output;
   
use strict;
use warnings;

use vars qw($output_object);

sub get {
   my ($class, $output_module) = @_;

   return $output_object if($output_object);

   return unless($output_module);

   eval "use Rex::Output::$output_module;";
   if($@) {
      die("Output Module ,,$output_module'' not found.");
   }

   my $output_class = "Rex::Output::$output_module";
   $output_object = $output_class->new;

   return $output_object;
}

1;
