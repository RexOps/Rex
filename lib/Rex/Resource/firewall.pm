#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::firewall - Firewall functions

=head1 DESCRIPTION

With this module it is easy to manage different firewall systems. 

=head1 SYNOPSIS

 # Configure a particular rule
 task "configure_firewall", "server01", sub {
   firewall "some-name",
     ensure      => "present",
     proto       => "tcp",
     action      => "accept",
     source      => "192.168.178.0/24",
     destination => "192.168.1.0/24",
     sport       => 80,
     sapp        => 'www',    # source application, if provider supports it
     port        => 80,       # same as dport
     dport       => 80,
     app         => 'www',    # same as dapp, destination application, if provider supports it
     dapp        => 'www',    # destination application, if provider supports it
     tcp_flags   => ["FIN", "SYN", "RST"],
     chain       => "INPUT",
     table       => "nat",
     jump        => "LOG",
     iniface     => "eth0",
     outiface    => "eth1",
     reject_with => "icmp-host-prohibited",
     log         => "new|all",  # if provider supports it
     log_level   => "",         # if provider supports it
     log_prefix  => "FW:",      # if provider supports it
     state       => "NEW",
     ip_version  => -4;         # for iptables provider. valid options -4 and -6
 };

 # Add overall logging (if provider supports)
 firewall "some-name",
   provider => 'ufw',
   logging  => "medium";

=head1 EXPORTED RESOURCES

=over 4

=cut

package Rex::Resource::firewall;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;

use Carp;

my $__provider = { default => "Rex::Resource::firewall::Provider::iptables", };

=item firewall($name, %params)

=cut

resource "firewall", { export => 1 }, sub {
  my $rule_name = resource_name;

  my $rule_config = {
    action      => param_lookup("action"),
    ensure      => param_lookup( "ensure",      "present" ),
    proto       => param_lookup( "proto",       undef ),
    source      => param_lookup( "source",      undef ),
    destination => param_lookup( "destination", undef ),
    port        => param_lookup( "port",        undef ),
    app         => param_lookup( "app",         undef ),
    sport       => param_lookup( "sport",       undef ),
    sapp        => param_lookup( "sapp",        undef ),
    dport       => param_lookup( "dport",       undef ),
    dapp        => param_lookup( "dapp",        undef ),
    tcp_flags   => param_lookup( "tcp_falgs",   undef ),
    chain       => param_lookup( "chain",       "input" ),
    table       => param_lookup( "table",       "filter" ),
    iniface     => param_lookup( "iniface",     undef ),
    outiface    => param_lookup( "outiface",    undef ),
    reject_with => param_lookup( "reject_with", undef ),
    logging     => param_lookup( "logging",     undef ),    # overall logging
    log         => param_lookup( "log",         undef ),    # logging for rule
    log_level   => param_lookup( "log_level",   undef ),    # logging for rule
    log_prefix  => param_lookup( "log_prefix",  undef ),
    state       => param_lookup( "state",       undef ),
    ip_version  => param_lookup( "ip_version",  -4 ),
  };

  my $provider =
    param_lookup( "provider", case ( lc(operating_system), $__provider ) );

  if ( $provider !~ m/::/ ) {
    $provider = "Rex::Resource::firewall::Provider::$provider";
  }

  $provider->require;
  my $provider_o = $provider->new();

  my $changed = 0;
  if ( my $logging = $rule_config->{logging} ) {
    if ( $provider_o->logging($logging) ) {
      emit changed, "Firewall logging updated.";
    }
  }
  elsif ( $rule_config->{ensure} eq "present" ) {
    if ( $provider_o->present($rule_config) ) {
      emit created, "Firewall rule created.";
    }
  }
  elsif ( $rule_config->{ensure} eq "absent" ) {
    if ( $provider_o->absent($rule_config) ) {
      emit removed, "Firewall rule removed.";
    }
  }
  elsif ( $rule_config->{ensure} eq "disabled" ) {
    if ( $provider_o->disable($rule_config) ) {
      emit changed, "Firewall disabled.";
    }
  }
  elsif ( $rule_config->{ensure} eq "enabled" ) {
    if ( $provider_o->enable($rule_config) ) {
      emit changed, "Firewall enabled.";
    }
  }
  else {
    die "Error: $rule_config->{ensure} not a valid option for 'ensure'.";
  }

};

=back

=cut

1;
