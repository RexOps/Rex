#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
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

=cut

package Rex::Commands::Service;

use strict;
use warnings;

# VERSION

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

use Rex::Service;
use Rex::Logger;
use Rex::Config;
use Rex::Hook;
use Carp;

@EXPORT = qw(service service_provider_for);

=head2 service($service, $action, [$option])

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
   service "apache2",
     ensure => "started";
 };

=item ensure that a service will NOT be started.

 task "prepare", sub {
   service "apache2",
     ensure => "stopped";
 };


If you need to define a custom command for start, stop, restart, reload or status you can do this with the corresponding options.

 task "prepare", sub {
   service "apache2",
     ensure  => "started",
     start   => "/usr/local/bin/httpd -f /etc/my/httpd.conf",
     stop    => "killall httpd",
     status  => "ps -efww | grep httpd",
     restart => "killall httpd && /usr/local/bin/httpd -f /etc/my/httpd.conf",
     reload  => "killall httpd && /usr/local/bin/httpd -f /etc/my/httpd.conf";
 };

This function supports the following L<hooks|Rex::Hook>:

=over 4

=item before_${action}

For example: C<before_start>, C<before_stop>, C<before_restart>

This gets executed right before the given service action. All original parameters are passed to it.

=item after_${action}

For example: C<after_start>, C<after_stop>, C<after_restart>

This gets executed right after the given service action. All original parameters, and any returned results are passed to it.

=back

=back

=cut

sub service {
  my ( $services, $action, @_options ) = @_;

  my $opt_ref = {};
  if ( scalar @_options >= 1 ) {
    $opt_ref = { $action, @_options };
  }
  else {
    $opt_ref = { ensure => $action, no_boot => 1 };
  }

  # $opt_ref = {
  #    ensure  => "start(ed)",
  #    no_boot => 1,
  #    ...     => ...,
  # }
  #######

  if (wantarray) {

    # func-ref zurueckgeben
    return sub {
      service( $services, $action );
    };

  }

  my $is_multiple = 1;
  unless ( ref($services) ) {
    $services    = [$services];
    $is_multiple = 0;
  }

  my $srvc = Rex::Service->get;

  my $changed = 0;
  my $return  = 1;
  for my $res_service (@$services) {

    my $service = $res_service;
    if ( exists $opt_ref->{name} ) {
      $service = $opt_ref->{name};
    }

    my $notify = Rex::get_current_connection()->{notify};
    $notify->add(
      type     => "service",
      name     => $service,
      postpone => 1,
      options  => {},
      cb       => sub {
        my ($option) = shift;
        Rex::Logger::debug("Restarting notified service: $service");
        service( $service => "restart" );
      }
    );

    #### check and run before_$action hook
    Rex::Hook::run_hook( service => "before_$action", @_ );
    ##############################

    if ( scalar @_ == 2 ) {
      return old_service( $service, $action );
    }

    ####### new service code

    Rex::get_current_connection()->{reporter}
      ->report_resource_start( type => "service", name => $res_service );

    my $b_status = $srvc->status($service);
    my $return;

    if ( $opt_ref->{ensure} =~ m/^(start|run|enable)/ ) {
      if ( exists $opt_ref->{no_boot} && $opt_ref->{no_boot} ) {
        $return = $srvc->start( $service, $opt_ref );
      }
      else {
        $return = $srvc->ensure( $service, $opt_ref );
      }
    }
    elsif ( $opt_ref->{ensure} =~ m/^(stop|disable)/ ) {
      if ( exists $opt_ref->{no_boot} && $opt_ref->{no_boot} ) {
        $return = $srvc->stop( $service, $opt_ref );
      }
      else {
        $return = $srvc->ensure( $service, $opt_ref );
      }
    }
    else {
      Rex::Logger::info( "$opt_ref->{ensure} unknown ensure value.", "error" );
      confess "$opt_ref->{ensure} unknown ensure value.";
    }

    my $a_status = $srvc->status( $service, $opt_ref );

    $changed = 0;
    if ( $a_status != $b_status ) {
      $changed = 1;
    }

    #### check and run after_$action hook
    Rex::Hook::run_hook(
      service => "after_$action",
      @_, { changed => $changed, ret => $return }
    );
    ##############################

    if ($changed) {
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Service $service changed status to $opt_ref->{ensure}."
      );
    }
    else {
      Rex::get_current_connection()->{reporter}->report( changed => 0, );
    }

    Rex::get_current_connection()->{reporter}
      ->report_resource_end( type => "service", name => $res_service );
  }

}

sub old_service {

  my ( $service, $action, $options ) = @_;

  my $srvc = Rex::Service->get;
  my $changed;
  my $is_multiple = 0;
  my $return;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "service", name => $service );

  if ( $action eq "start" ) {

    unless ( $srvc->status($service) ) {
      $changed = 1;
      if ( $srvc->start($service) ) {
        Rex::Logger::info("Service $service started.");
        $return = 1 if !$is_multiple;
      }
      else {
        Rex::Logger::info( "Error starting $service.", "warn" );
        $return = 0 if !$is_multiple;
      }
    }

  }

  elsif ( $action eq "restart" ) {
    $changed = 1;

    if ( $srvc->restart($service) ) {
      Rex::Logger::info("Service $service restarted.");
      $return = 1 if !$is_multiple;
    }
    else {
      Rex::Logger::info( "Error restarting $service.", "warn" );
      $return = 0 if !$is_multiple;
    }

  }

  elsif ( $action eq "stop" ) {

    if ( $srvc->status($service) ) { # it runs
      $changed = 1;
      if ( $srvc->stop($service) ) {
        Rex::Logger::info("Service $service stopped.");
        $return = 1 if !$is_multiple;
      }
      else {
        Rex::Logger::info( "Error stopping $service.", "warn" );
        $return = 0 if !$is_multiple;
      }
    }

  }

  elsif ( $action eq "reload" ) {
    $changed = 1;
    if ( $srvc->reload($service) ) {
      Rex::Logger::info("Service $service is reloaded.");
      $return = 1 if !$is_multiple;
    }
    else {
      Rex::Logger::info( "Error $service does not support reload", "warn" );
      $return = 0 if !$is_multiple;
    }

  }

  elsif ( $action eq "status" ) {

    $changed = 100;
    if ( $srvc->status($service) ) {
      Rex::Logger::info("Service $service is running.");
      $return = 1 if !$is_multiple;
    }
    else {
      Rex::Logger::info("$service is stopped");
      $return = 0 if !$is_multiple;
    }

  }

  elsif ( $action eq "ensure" ) {

    if ( $srvc->ensure( $service, { ensure => $options } ) ) {
      $changed = 0;
      $return  = 1 if !$is_multiple;
    }
    else {
      $return = 0 if !$is_multiple;
      Rex::Logger::info("Error ensuring $service to $options");
    }
  }

  else {
    Rex::Logger::info("Executing action $action on $service.");
    $srvc->action( $service, $action );
    $changed = 100;
  }

  if ($changed) {
    Rex::get_current_connection()->{reporter}
      ->report( changed => $changed, message => "Service executed $action." );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "service", name => $service );

  return $return;
}

=head2 service_provider_for $os => $type;

To set another service provider as the default, use this function.

 user "root";

 group "db" => "db[01..10]";
 service_provider_for SunOS => "svcadm";

 task "start", group => "db", sub {
    service ssh => "restart";
 };

This example will restart the I<ssh> service via svcadm (but only on SunOS, on other operating systems it will use the default).

=cut

sub service_provider_for {
  my ( $os, $provider ) = @_;
  Rex::Logger::debug("setting service provider for $os to $provider");
  Rex::Config->set( "service_provider", { $os => $provider } );
}

1;
