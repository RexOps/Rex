#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Exporter;
   
use strict;
use warnings;

use Data::Dumper;

our @EXPORT;

no strict 'refs';

sub import {
   my ($mod_to_register, %option) = @_;
   my ($mod_to_register_in, $file, $line) = caller;

   if($option{register_in}) {
      $mod_to_register_in = $option{register_in};
   }

   for my $reg_func (@{ $_[0] . "::EXPORT" }) {
      *{ $mod_to_register_in . "::" . $reg_func } = *{ $mod_to_register . "::" . $reg_func };
   }
}

use strict;
   
1;
