#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Kernel;

use strict;
use warnings;

use Rex::Commands::Run;

sub get {

   return {
      architecture => run ("uname -m"),
      kernel       => run ("uname -s"),
      kernelrelease => run ("uname -r"),
      kernelversion => run ("uname -v"),
   };

}

1;
