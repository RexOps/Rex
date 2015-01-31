#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::UFW - UFW Management Commands

=head1 DESCRIPTION

With this Module you can manage UFW (Uncomplicated Firewall) rules.

=head1 SYNOPSIS

 use Rex::Commands::UFW;

 ufw_enable; # Activate firewall

 ufw_disable; # Disable firewall

 ufw_logging 'on';

 ufw_allow app => 'www';

 ufw_allow app => 'www', delete => 1;

 ufw_allow
   from => '10.10.10.1',
   app  => 'www',
   to   => '192.168.0.1',
   app  => 'www',
   log  => 'new';

 # Delete a rule
 ufw_allow
   from   => '10.10.10.1',
   app    => 'www',
   to     => '192.168.0.1',
   app    => 'www',
   log    => 'new',
   delete => 1;

 ufw_allow
   proto     => 'tcp',
   from      => '10.10.10.1',
   port      => 22,
   to        => '192.168.0.1',
   port      => 80,
   direction => 'in',
   on        => 'eth0',
   log       => 'all';

  ufw_limit app => 'OpenSSH';
 
=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::UFW;

use strict;
use warnings;

# VERSION

require Rex::Exporter;

use base qw(Rex::Exporter);

use vars qw(@EXPORT);

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Logger;

@EXPORT = qw(ufw_enable ufw_disable ufw_logging ufw_allow
  ufw_deny ufw_reject ufw_limit);

=item ufw_enable

Enable UFW firewall.

=cut

sub ufw_enable { _ufw_disable_enable('enable') }

=item ufw_disable

Disable UFW firewall.

=cut

sub ufw_disable { _ufw_disable_enable('disable') }

sub _ufw_disable_enable {
  my $action = shift;
  _resource_start($action);
  my $return = _ufw_exec('status');

  my $needed = $action eq 'enable' ? 'inactive' : 'active';
  if ( $return =~ /Status: $needed/ ) {
    my $ret = _ufw_exec("--force $action");
    my $success = $action eq 'enable'
                ? 'Firewall is active and enabled'
                : 'Firewall stopped and disabled';
    if ($ret =~ /$success/) {
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Firewall successfully changed to $action",
      );
    }
    else {
      Rex::Logger::info( "Unexpected ufw response: $ret", "warn" );
    }
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }
  _resource_end($action);
}

=item ufw_logging($status)

Configure UFW logging. status is as-per ufw, and can be any
of on, off, low, medium, high, full. Defaults to low.

=cut

sub ufw_logging {
  my $param = shift;

  $param =~ /(on|off|low|medium|high|full)/
    or die "Invalid logging parameter: $param";

  _resource_start('logging');
  my $current = _ufw_exec('status verbose');

  my $need_update;
  if ($param eq 'on') {
    $need_update = 1 unless $current =~ /^Logging: on/m;
  }
  elsif ($param eq 'off') {
    $need_update = 1 unless $current =~ /^Logging: off$/m
  }
  else {
    $need_update = 1 unless $current =~ /^Logging: on \($param\)$/m;
  }

  if ( $need_update ) {
    my $ret = _ufw_exec("logging $param");
    my $success = $param eq 'off'
                ? 'Logging disabled'
                : 'Logging enabled';
    if ($ret eq $success) {
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Firewall logging successfully changed to $param",
      );
    }
    else {
      Rex::Logger::info( "Unexpected ufw response: $ret", "warn" );
    }
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }
  _resource_end('logging');
}

=item ufw_allow(%options)

=item ufw_deny(%options)

=item ufw_allow(%options)

=item ufw_allow(%options)

Add or remove a firewall rule

Options can be any of:

=over 2

=item proto

The protocol, either tcp or udp. Defaults to any.

=item from

=item to

The destination or source IP address, in a format as expected by ufw.
Can also be optionally followed by C<port> or C<app>. Defaults to any.

 from => "192.168.0.1", app => "www"

 to => "192.168.0.1", port => "22"

=item direction

Whether the rule should be ingress or egress. Ufw defaults to in.

 direction => 'out'

=item on

The interface this rule applies to. Defaults to all interfaces.

 on => 'eth0'

=item log

Whether to log packets that match the rule. By default no logging is
performed.

 log => 'new' # Log only new connections

 log => 'all' # Log all packets

=item app

Use a UFW-defined application. As with ufw, this can either be used
on its own, or in conjunction with IP addresses. It can also be used
with C<log>, C<direction> and C<on>, but not with C<proto> or C<port>

=back

=cut

sub ufw_allow { _ufw_rule ( 'allow', @_ ) }
sub ufw_deny { _ufw_rule ( 'deny', @_ ) }
sub ufw_reject { _ufw_rule ( 'reject', @_ ) }
sub ufw_limit { _ufw_rule ( 'limit', @_ ) }

sub _ufw_rule {

  my ( $action, @params) = @_;

  my %torun = (
    action   => $action, # allow, deny, limit etc
    commands => [],
  );

  my $has_app; # Has app parameters
  my $has_port; # Has port parameters

  while (my $param = shift @params) {
    if ( $param eq 'proto' ) {
      my $proto = shift @params;
      die "Invalid protocol $proto"
        unless ($proto eq 'tcp' || $proto eq 'udp');
      $torun{proto} = "proto $proto";
    }
    elsif ( $param eq 'from' || $param eq 'to' ) {
      my $address = shift @params;
      push @{$torun{commands}}, ($param => $address);
      # See if next rule is a port
      if ( $params[0] && $params[0] eq 'port' ) {
        shift @params;
        my $port = shift @params;
        push @{$torun{commands}}, (port => $port);
        $has_port = 1;
      }
      elsif ( $params[0] && $params[0] eq 'app' ) {
        shift @params;
        my $app = shift @params;
        push @{$torun{commands}}, (app => $app);
        $has_app = 1;
      }
    }
    elsif ( $param eq 'app' ) {
      # App can appear on its own, or in combination with from/to above
      my $app = shift @params;
      $torun{app} = $app;
      $has_app = 1;
    }
    elsif ( $param eq 'direction' ) {
      my $direction = shift @params;
      die "Invalid direction $direction"
        unless ($direction eq 'in' || $direction eq 'out');
      $torun{direction} = $direction;
      # See if next rule is an interface
      if ( $params[0] && $params[0] eq 'on' ) {
        shift @params;
        my $interface = shift @params;
        $torun{on} = "on $interface";
      }
    }
    elsif ( $param eq 'log' ) {
      my $log = shift @params;
      if ($log eq 'new') {
        $torun{log} = 'log';
      }
      elsif ($log eq 'all') {
        $torun{log} = 'log-all';
      }
      else {
        die "Invalid logging option $log";
      }
    }
    elsif ( $param eq 'delete' )
    {
      $torun{delete} = 'delete' if shift @params;
    }
    else {
      die qq(Unexpected parameter "$param" supplied to ufw rule $action);
    }
  }

  die "Do not specify port parameter with app parameter"
    if $has_app && $has_port;

  die "Do not specify protocol parameter with app parameter"
    if $has_app && $torun{proto};

  my $cmd;
  for my $param (qw/delete action direction on log app proto/) {
    $cmd .= " $torun{$param}" if $torun{$param};
  }
  $cmd .= " @{$torun{commands}}";

  _resource_start($torun{action});
  my $return = _ufw_exec($cmd);

  if ( $return =~ /(inserted|updated|deleted|added)/ ) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Rules successfully updated",
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }
  _resource_end($torun{action});
}

sub _resource_start {
  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "ufw", name => shift );
}

sub _resource_end {
  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "ufw", name => shift );
}

sub _ufw_exec {
  my $cmd = shift;

  $cmd = "ufw $cmd";

  if ( can_run("ufw") ) {
    my ( $output, $err ) = i_run $cmd, sub { @_ };

    if ( $? != 0 ) {
      Rex::Logger::info( "Error running ufw command: $cmd, received $err", "warn" );
      die("Error running ufw rule: $cmd");
    }
    Rex::Logger::debug("Output from ufw: $output");
    return $output;
  }
  else {
    Rex::Logger::info("UFW not found.");
    die("UFW not found.");
  }
}

=back

=cut

1;
