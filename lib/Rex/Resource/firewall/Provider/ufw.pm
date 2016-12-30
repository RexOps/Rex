#
# (c) Andrew Beverley
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::firewall::Provider::ufw;

use strict;
use warnings;

# VERSION

use Data::Dumper;
use Rex::Commands::Run;
use Rex::Helper::Run;

use base qw(Rex::Resource::firewall::Provider::base);

my %__action_map = (
  accept => "allow",
  allow  => "allow",
  deny   => "deny", ## -j DROP
  drop   => "deny", ## -j DROP
  reject => "reject", ## -j REJECT
  limit  => "limit",
);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub present {
  my ( $self, $rule_config ) = @_;

  my @ufw_params = $self->_generate_rule_array($rule_config);

  return $self->_ufw_rule( grep { defined } @ufw_params );
}

sub absent {
  my ( $self, $rule_config ) = @_;

  $rule_config->{delete} = 1;
  my @ufw_params = $self->_generate_rule_array($rule_config);

  return $self->_ufw_rule( grep { defined } @ufw_params );
}

sub enable {
  my ( $self, $rule_config ) = @_;
  return $self->_ufw_disable_enable("enable");
}

sub disable {
  my ( $self, $rule_config ) = @_;
  return $self->_ufw_disable_enable("disable");
}

sub logging {
  my ( $self, $logging ) = @_;
  return $self->_ufw_logging($logging);
}

sub _ufw_rule {

  my ( $self, $action, @params ) = @_;
  my %torun = (
    action   => $action, # allow, deny, limit etc
    commands => [],
  );

  my $has_app;           # Has app parameters
  my $has_port;          # Has port parameters

  while ( my $param = shift @params ) {
    if ( $param eq 'proto' ) {
      my $proto = shift @params;
      die "Invalid protocol $proto"
        unless ( $proto eq 'tcp' || $proto eq 'udp' );
      $torun{proto} = "proto $proto";
    }
    elsif ( $param eq 'from' || $param eq 'to' ) {
      my $address = shift @params;
      push @{ $torun{commands} }, ( $param => $address );

      # See if next rule is a port
      if ( $params[0] && $params[0] eq 'port' ) {
        shift @params;
        my $port = shift @params;
        push @{ $torun{commands} }, ( port => $port );
        $has_port = 1;
      }
      elsif ( $params[0] && $params[0] eq 'app' ) {
        shift @params;
        my $app = shift @params;
        push @{ $torun{commands} }, ( app => $app );
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
        unless ( $direction eq 'in' || $direction eq 'out' );
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
      if ( $log eq 'new' ) {
        $torun{log} = 'log';
      }
      elsif ( $log eq 'all' ) {
        $torun{log} = 'log-all';
      }
      else {
        die "Invalid logging option $log";
      }
    }
    elsif ( $param eq 'delete' ) {
      $torun{delete} = 'delete' if shift @params;
    }
    elsif ( $param =~ m/^\d+(\/(tcp|udp))?$/ ) {
      if ( scalar @{ $torun{commands} } == 0 ) {
        push @{ $torun{commands} }, $param;
      }
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

  my $return = $self->_ufw_exec($cmd);

  if ( $return =~ /(inserted|updated|deleted|added)/ ) {
    return 1;
  }

  return 0;
}

sub _ufw_disable_enable {
  my $self   = shift;
  my $action = shift;
  my $return = $self->_ufw_exec('status');

  my $needed = $action eq 'enable' ? 'inactive' : 'active';
  if ( $return =~ /Status: $needed/ ) {
    my $ret = $self->_ufw_exec("--force $action");
    my $success =
      $action eq 'enable'
      ? 'Firewall is active and enabled'
      : 'Firewall stopped and disabled';
    if ( $ret =~ /$success/ ) {
      return 1;
    }
    else {
      Rex::Logger::info( "Unexpected ufw response: $ret", "warn" );
    }
  }

  return 0;
}

sub _ufw_logging {
  my $self  = shift;
  my $param = shift;

  $param =~ /(on|off|low|medium|high|full)/
    or die "Invalid logging parameter: $param";

  my $current = $self->_ufw_exec('status verbose');

  my $need_update;
  if ( $param eq 'on' ) {
    $need_update = 1 unless $current =~ /^Logging: on/m;
  }
  elsif ( $param eq 'off' ) {
    $need_update = 1 unless $current =~ /^Logging: off$/m;
  }
  else {
    $need_update = 1 unless $current =~ /^Logging: on \($param\)$/m;
  }

  if ($need_update) {
    my $ret = $self->_ufw_exec("logging $param");
    my $success =
      $param eq 'off'
      ? 'Logging disabled'
      : 'Logging enabled';
    if ( $ret eq $success ) {
      return 1;
    }
    else {
      Rex::Logger::info( "Unexpected ufw response: $ret", "warn" );
    }
  }
}

sub _ufw_exec {
  my $self = shift;
  my $cmd  = shift;

  $cmd = "ufw $cmd";

  if ( can_run("ufw") ) {
    my ( $output, $err ) = i_run $cmd, sub { @_ }, fail_ok => 1;

    if ( $? != 0 ) {
      Rex::Logger::info( "Error running ufw command: $cmd, received $err",
        "warn" );
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

sub _generate_rule_array {
  my ( $self, $rule_config ) = @_;

  my $action = $__action_map{ $rule_config->{action} }
    or die qq(Unknown action "$rule_config->{action}" for UFW provider);
  $rule_config->{dport}       ||= $rule_config->{port};
  $rule_config->{dapp}        ||= $rule_config->{app};
  $rule_config->{source}      ||= "any";
  $rule_config->{destination} ||= "any";

  my @ufw_params = ();
  push @ufw_params, $action;

  push( @ufw_params, "proto", $rule_config->{proto} )
    if ( defined $rule_config->{proto} );

  push( @ufw_params, "from", $rule_config->{source} )
    if ( defined $rule_config->{source} );

  push( @ufw_params, "port", $rule_config->{sport} )
    if ( defined $rule_config->{sport} );

  push( @ufw_params, "app", qq("$rule_config->{sapp}") )
    if ( defined $rule_config->{sapp} );

  push( @ufw_params, "to", $rule_config->{destination} )
    if ( defined $rule_config->{destination} );

  push( @ufw_params, "port", $rule_config->{dport} )
    if ( defined $rule_config->{dport} );

  push( @ufw_params, "app", qq("$rule_config->{dapp}") )
    if ( defined $rule_config->{dapp} );

  push( @ufw_params, "direction", "in" )
    if ( defined $rule_config->{iniface} );

  push( @ufw_params, "on", $rule_config->{iniface} )
    if ( defined $rule_config->{iniface} );

  push( @ufw_params, "log", $rule_config->{log} )
    if ( defined $rule_config->{log} );

  push( @ufw_params, "delete", $rule_config->{delete} )
    if ( defined $rule_config->{delete} );

  return @ufw_params;
}

1;
