#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virt;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT $username $password $type);

use Rex::Logger;

@EXPORT = qw(virt);

sub virt {
   my ($action, $arg1, %opt) = @_;

   my $mod = "Rex::Virt::$action";
   eval "use $mod;";

   if($@) {
      Rex::Logger::info("No action $action available.");
      exit 2;
   }

   return $mod->execute($arg1, %opt);
}

1;
