#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Gather;

use strict;
use warnings;

use Rex::Hardware;
use Rex::Hardware::Host;

require Exporter;
use base qw(Exporter);

use vars qw(@EXPORT);

@EXPORT = qw(operating_system_is);

sub operating_system_is {

   my ($os) = @_;

   my $host = Rex::Hardware::Host->get();

   if($host->{"operatingsystem"} eq $os) {
      return 1;
   }

   return 0;

}

1;
