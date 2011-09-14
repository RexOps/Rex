#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Virtualization;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Config;

@EXPORT = qw(virt);

sub virt {
   my ($action, $vmname, %opt) = @_;

   my $type = Rex::Config->get("virtualization");

   Rex::Logger::debug("Using $type for virtualization");

   my $mod = "Rex::Virtualization::${type}::${action}";
   eval "use $mod;";

   if($@) {
      Rex::Logger::info("No module/action $type/$action available.");
      die("No module/action $type/$action available.");
   }

   return $mod->execute($vmname, %opt);
}

1;
