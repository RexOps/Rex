#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Service;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

use Rex::Service;

@EXPORT = qw(service);

sub service {
   my ($service, $action) = @_;

   if(wantarray) {
   
      # func-ref zurueckgeben
      return sub {
         service($service, $action);
      };

   }

   my $srvc = Rex::Service->get;

   if($action eq "start") {

      unless($srvc->status($service)) {
         if($srvc->start($service)) {
            Rex::Logger::info("Service $service started.");
            return 1;
         }
         else {
            Rex::Logger::info("Error starting $service.");
            return 0;
         }
      }

   }

   elsif($action eq "restart") {

      if($srvc->restart($service)) {
         Rex::Logger::info("Service $service restarted.");
         return 1;
      }
      else {
         Rex::Logger::info("Error restarting $service.");
         return 0;
      }

   }

   elsif($action eq "stop") {

      if($srvc->stop($service)) {
         Rex::Logger::info("Service $service stopped.");
         return 1;
      }
      else {
         Rex::Logger::info("Error stopping $service.");
         return 0;
      }

   }

   elsif($action eq "status") {

      if($srvc->status($service)) {
         Rex::Logger::info("Service $service is running.");
         return 1;
      }
      else {
         Rex::Logger::info("$service is stopped");
         return 0;
      }

   }

   else {
   
      Rex::Logger::info("$action not supported.");

   }
}

1;
