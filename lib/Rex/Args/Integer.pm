#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Args::Integer;
   
use strict;
use warnings;

use Rex::Logger;

sub get {
   my ($class, $name) = @_;

   my $arg = shift @ARGV;

   if($arg =~ m/^\d+$/) {
      return $arg;
   }

   Rex::Logger::debug("Invalid argument for $name");

   return undef;
}

1;
