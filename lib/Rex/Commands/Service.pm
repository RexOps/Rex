#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Service - Manage System Services

=head1 DESCRIPTION

With this module you can manage Linux services.

=head1 SYNOPSIS

 use Rex::Commands::Service
     
 service apache2 => "start";
     
 service apache2 => "stop";
     
 service apache2 => "restart";
     
 service apache2 => "status";
    
 service apache2 => "reload";
    
 service apache2 => "ensure", "started";
   
 service apache2 => "ensure", "stopped";

=head1 EXPORTED FUNCTIONS

=over 4

=cut



package Rex::Commands::Service;

use strict;
use warnings;

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

use Rex::Service;
use Rex::Logger;
use Rex::Config;
use Rex::Hook;

@EXPORT = qw(service service_provider_for);

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


=item ensure that a service will started at boot time

 task "prepare", sub {
    service apache2 => "ensure", "started";
 };

=item ensure that a service will NOT be started.

 task "prepare", sub {
    service apache2 => "ensure", "stopped";
 };


This function supports the following hooks:

=over 8


=item before_I<action>

For example: before_start, before_stop, before_restart

This gets executed right before the service action.

=item after_I<action>

For example: after_start, after_stop, after_restart

This gets executed right after the service action.

=back

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

   my $is_multiple = 1;
   unless(ref($services)) {
      $services = [$services];
      $is_multiple = 0;
   }

   my $srvc = Rex::Service->get;

   my $changed = 0;
   my $return = 1;
   for my $service (@$services) {

      #### check and run before_$action hook
      Rex::Hook::run_hook(service => "before_$action", @_);
      ##############################


      if($action eq "start") {

         unless($srvc->status($service)) {
            $changed = 1;
            if($srvc->start($service)) {
               Rex::Logger::info("Service $service started.");
               $return = 1 if ! $is_multiple;
            }
            else {
               Rex::Logger::info("Error starting $service.", "warn");
               $return = 0 if ! $is_multiple;
            }
         }

      }

      elsif($action eq "restart") {
         $changed = 1;

         if($srvc->restart($service)) {
            Rex::Logger::info("Service $service restarted.");
            $return = 1 if ! $is_multiple;
         }
         else {
            Rex::Logger::info("Error restarting $service.", "warn");
            $return = 0 if ! $is_multiple;
         }

      }

      elsif($action eq "stop") {

         if($srvc->status($service)) { # it runs
            $changed = 1;
            if($srvc->stop($service)) {
               Rex::Logger::info("Service $service stopped.");
               $return = 1 if ! $is_multiple;
            }
            else {
               Rex::Logger::info("Error stopping $service.", "warn");
               $return = 0 if ! $is_multiple;
            }
         }

      }

      elsif($action eq "reload") {
         $changed = 1;
         if($srvc->reload($service)) {
            Rex::Logger::info("Service $service is reloaded.");
            $return = 1 if ! $is_multiple;
         }
         else {
            Rex::Logger::info("Error $service does not support reload", "warn");
            $return = 0 if ! $is_multiple;
         }

      }

      elsif($action eq "status") {

         $changed = 100;
         if($srvc->status($service)) {
            Rex::Logger::info("Service $service is running.");
            $return = 1 if ! $is_multiple;
         }
         else {
            Rex::Logger::info("$service is stopped");
            $return = 0 if ! $is_multiple;
         }

      }

      elsif($action eq "ensure") {

         if($srvc->ensure($service, $options)) {
            $changed = 0;
            $return = 1 if ! $is_multiple;
         }
         else {
            $return = 0 if ! $is_multiple;
            Rex::Logger::info("Error ensuring $service to $options");
         }
      }

      else {
         Rex::Logger::info("Execution action $action on $service.");
         $srvc->action($service, $action);
         $changed = 100;
      }

      #### check and run after_$action hook
      Rex::Hook::run_hook(service => "after_$action", @_, {changed => $changed, ret => $ret});
      ##############################

   }

   if(Rex::Config->get_do_reporting) {
      if($changed == 100) {
         return {
            skip => 1,
            ret  => $return,
         };
      }
      return {
         changed => $changed,
         ret     => $return,
      };
   }

   return $return;
}

=item service_provider_for $os => $type;

To set an other service provider as the default, use this function.

 user "root";
     
 group "db" => "db[01..10]";
 service_provider_for SunOS => "svcadm";
    
 task "start", group => "db", sub {
     service ssh => "restart";
 };

This example will restart the I<ssh> service via svcadm (but only on SunOS, on other operating systems it will use the default).

=cut
sub service_provider_for {
   my ($os, $provider) = @_;
   Rex::Logger::debug("setting service provider for $os to $provider");
   Rex::Config->set("service_provider", {$os => $provider});
}



=back

=cut

1;
