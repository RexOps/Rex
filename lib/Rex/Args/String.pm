#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Args::String;
   
use strict;
use warnings;

sub get {
   my ($class, $name) = @_;

   my $arg = shift @ARGV;
   return $arg;
}

1;
