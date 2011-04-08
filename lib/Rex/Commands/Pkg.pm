#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Pkg;

use strict;
use warnings;

use Rex::Pkg;
use Rex::Logger;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(install remove);

sub install {

   my ($type, $package, $option) = @_;


   if($type eq "package") {

      my $pkg = Rex::Pkg->get;

      unless($pkg->is_installed($package)) {
         Rex::Logger::info("Installing $package.");
         $pkg->install($package);
      }
      else {
         Rex::Logger::info("$package already installed.");
      }

   }

   else {
      
      Rex::Logger::info("$type not supported.");
      exit 1;

   }


}

sub remove {
}

1;
