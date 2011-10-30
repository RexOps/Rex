#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Output;

use strict;
use warnings;

sub get {
   my ($class, $output_module) = @_;

   eval "use Rex::Output::$output_module;";
   if($@) {
      die("Output Module ,,$output_module'' not found.");
   }

   my $output_class = "Rex::Output::$output_module";

   return $output_class->new;
}

1;
