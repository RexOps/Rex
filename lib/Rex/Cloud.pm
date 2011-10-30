#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Cloud;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;

@EXPORT = qw(get_cloud_service);

sub get_cloud_service {

   my ($service) = @_;

   eval "use Rex::Cloud::$service";
   if($@) {
      Rex::Logger::info("Cloud Service $service not supported.");
      Rex::Logger::info($@);
      return 0;
   }

   my $mod = "Rex::Cloud::$service";
   return $mod->new;

}

1;
