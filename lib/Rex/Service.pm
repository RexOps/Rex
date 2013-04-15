#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Service;

use strict;
use warnings;

use Rex::Config;
use Rex::Commands::Run;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

my %SERVICE_PROVIDER;
sub register_service_provider {
   my ($class, $service_name, $service_class) = @_;
   $SERVICE_PROVIDER{"\L$service_name"} = $service_class;
   return 1;
}

sub get {

   my $operatingsystem = Rex::Hardware::Host->get_operating_system();
   my $can_run_systemctl = can_run("systemctl");
   my $class;

   $class = "Rex::Service::" . $operatingsystem;
   if(is_redhat($operatingsystem) && $can_run_systemctl) {
      $class = "Rex::Service::Redhat::systemd";
   } elsif (is_redhat($operatingsystem)) {
      # this also counts for fedora, centos, ...
      $class = "Rex::Service::Redhat";
   } elsif(is_suse($operatingsystem) && $can_run_systemctl) {
      $class = "Rex::Service::SuSE::systemd";
   } elsif (is_alt($operatingsystem) && $can_run_systemctl) {
      $class = "Rex::Service::ALT::systemd";
   }

   my $provider_for = Rex::Config->get("service_provider") || {};
   my $provider;

   if(ref($provider_for) && exists $provider_for->{$operatingsystem}) {
      $provider = $provider_for->{$operatingsystem};
      $class .= "::\L$provider";
   }
   elsif(exists $SERVICE_PROVIDER{$provider_for}) {
      $class = $SERVICE_PROVIDER{$provider_for};
   }

   Rex::Logger::debug("service using class: $class");
   eval "use $class";

   if($@) {

      Rex::Logger::info("OS ($operatingsystem) not supported");
      exit 1;

   }

   return $class->new;

}

1;
