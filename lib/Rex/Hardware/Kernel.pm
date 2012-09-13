#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Kernel;

use strict;
use warnings;

use Rex::Commands::Run;

require Rex::Hardware;

sub get {

   if(my $ret = Rex::Hardware->cache("Kernel")) {
      return $ret;
   }

   return {
      architecture => run ("LC_ALL=C uname -m"),
      kernel       => run ("LC_ALL=C uname -s"),
      kernelrelease => run ("LC_ALL=C uname -r"),
      kernelversion => run ("LC_ALL=C uname -v"),
   };

}

1;
