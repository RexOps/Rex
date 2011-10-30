#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg;

use strict;
use warnings;

use Rex::Config;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

use Data::Dumper;

sub get {

   my ($self) = @_;

   my $host = Rex::Hardware::Host->get();
   my $pkg_provider_for = Rex::Config->get("package_provider") || {};

   #if(lc($host->{"operatingsystem"}) eq "centos" || lc($host->{"operatingsystem"}) eq "redhat") {
   if(is_redhat()) {
      $host->{"operatingsystem"} = "Redhat";
   }

   my $class = "Rex::Pkg::" . $host->{"operatingsystem"};

   my $provider;
   if(exists $pkg_provider_for->{$host->{"operatingsystem"}}) {
      $provider = $pkg_provider_for->{$host->{"operatingsystem"}};
      $class .= "::$provider";
   }

   eval "use $class";

   if($@) {

      if($provider) {
         Rex::Logger::info("Provider not supported (" . $provider . ")");
      }
      else {
         Rex::Logger::info("OS not supported (" . $host->{"operatingsystem"} . ")");
      }
      die("OS/Provider not supported");

   }

   return $class->new;

}

1;
