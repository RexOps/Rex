#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Sysctl;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sysctl);

sub sysctl {

   my ($key, $val) = @_;

   if($val) {

      Rex:Logger::debug("Setting sysctl key $key to $val");
      run "/sbin/sysctl -w $key=$val";

   }
   else {
   
      my $ret = run "/sbin/sysctl -n $key";
      if($? == 0) {
         return $ret;
      }
      else {
         Rex::Logger::info("Error getting sysctl key: $key");
         return -255;
      }

   }

}

1;
