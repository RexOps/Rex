#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Service - Manage System Services

=head1 DESCRIPTION

With this module you can manage Linux services.

Currently this module supports

=over 4

=item Debian

=item CentOS

=item OpenSuSE

=back

=head1 SYNOPSIS

 use Rex::Commands::Service
 
 service apache2 => "start";
 
 service apache2 => "stop";
 
 service apache2 => "restart";
 
 service apache2 => "status";

=head1 EXPORTED FUNCTIONS

=over 4

=cut



package Rex::Commands::Service;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

use Rex::Service;

@EXPORT = qw(service);

=item service($service, $action, [$option])

The service function accepts 2 parameters. The first is the service name and the second the action you want to perform.

=over 4

=item starting a service

 task "start-service", "server01", sub {
    service apache2 => "start";
 };

=item stopping a service

 task "stop-service", "server01", sub {
    service apache2 => "stop";
 };

=item restarting a service

 task "restart-service", "server01", sub {
    service apache2 => "restart";
 };


=item checking status of a service

 task "status-service", "server01", sub {
    if( service apache2 => "status" ) {
       say "Apache2 is running";
    }
    else {
       say "Apache2 is not running";
    }
 };

=item reloading a service

 task "reload-service", "server01", sub {
    service apache2 => "reload";
 };



=back

=cut

sub service {
   my ($services, $action, $options) = @_;

   if(wantarray) {
   
      # func-ref zurueckgeben
      return sub {
         service($services, $action);
      };

   }

   unless(ref($services)) {
      $services = [$services];
   }

   my $srvc = Rex::Service->get;

   for my $service (@{$services}) {

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

      elsif($action eq "reload") {

         if($srvc->reload($service)) {
            Rex::Logger::info("Service $service is reloaded.");
            return 1;
         }
         else {
            Rex::Logger::info("Error $service does not support reload");
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

      elsif($action eq "ensure") {

         $srvc->ensure($service, $options);

      }

      else {
      
         Rex::Logger::info("$action not supported.");

      }

   }

}

=back

=cut

1;
