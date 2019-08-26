#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::firewall::Provider::iptables;

use strict;
use warnings;

# VERSION

use Moose;

extends qw(Rex::Resource::firewall::Provider::base);
with qw(Rex::Resource::Role::Ensureable);

use Rex::Commands::Iptables;
use Rex::Helper::Run;
use Rex::Resource::Common;

use Data::Dumper;

sub test {
  my ($self) = @_;

  my $rule_config   = $self->config;
  my @iptables_rule = $self->_build_iptables_array("A");

  my $exists =
    Rex::Commands::Iptables::_rule_exists( $rule_config->{ip_version},
    @iptables_rule );

  if ( $self->config->{ensure} eq "absent" && $exists ) {
    return 0;
  }
  elsif ( $self->config->{ensure} eq "present" && !$exists ) {
    return 0;
  }

  return 1;
}

sub present {
  my ($self) = @_;

  my @iptables_rule = $self->_build_iptables_array("A");
  my $exit_code     = 0;
  eval {
    iptables( $self->config->{ip_version}, @iptables_rule );
    1;
  } or do {
    $exit_code = 1;
  };

  return {
    value     => "",
    exit_code => $exit_code,
    changed   => 1,
    status    => ( $exit_code == 0 ? state_changed : state_failed ),
  };
}

sub absent {
  my ($self) = @_;

  my @iptables_rule = $self->_build_iptables_array("D");
  my $exit_code     = 0;
  eval {
    iptables( $self->config->{ip_version}, @iptables_rule );
    1;
  } or do {
    $exit_code = 1;
  };

  return {
    value     => "",
    exit_code => $exit_code,
    changed   => 1,
    status    => ( $exit_code == 0 ? state_changed : state_failed ),
  };
}

sub _version {
  my ($self) = @_;
  if ( exists $self->{__version__} ) { return $self->{__version__} }

  my $version = i_run "iptables --version";
  $version =~ s/^.*\sv(\d+\.\d+\.\d+)/$1/;

  $self->{__version__} = [ split( /\./, $version ) ];

  Rex::Logger::debug(
    "Got iptables version: " . join( ", ", @{ $self->{__version__} } ) );

  return $self->{__version__};
}

sub _build_iptables_array {
  my ( $self, $type ) = @_;
  my $rule_config = $self->config;

  my @iptables_rule = ();

  if ( $rule_config->{source}
    && $rule_config->{source} !~ m/\/(\d+)$/
    && $self->_version()->[0] >= 1
    && $self->_version()->[1] >= 4 )
  {
    $rule_config->{source} .= "/32";
  }

  push( @iptables_rule, t => $rule_config->{table} )
    if ( defined $rule_config->{table} );
  push( @iptables_rule, $type => uc( $rule_config->{chain} ) )
    if ( defined $rule_config->{chain} );
  push( @iptables_rule, p => $rule_config->{proto} )
    if ( defined $rule_config->{proto} );
  push( @iptables_rule, m => $rule_config->{proto} )
    if ( defined $rule_config->{proto} );
  push( @iptables_rule, s => $rule_config->{source} )
    if ( defined $rule_config->{source} );
  push( @iptables_rule, d => $rule_config->{destination} )
    if ( defined $rule_config->{destination} );
  push( @iptables_rule, sport => $rule_config->{sport} )
    if ( defined $rule_config->{sport} );
  push( @iptables_rule, dport => $rule_config->{dport} )
    if ( defined $rule_config->{dport} );
  push( @iptables_rule, "tcp-flags" => $rule_config->{tcp_flags} )
    if ( defined $rule_config->{tcp_flags} );
  push( @iptables_rule, "i" => $rule_config->{iniface} )
    if ( defined $rule_config->{iniface} );
  push( @iptables_rule, "o" => $rule_config->{outiface} )
    if ( defined $rule_config->{outiface} );
  push( @iptables_rule, "reject-with" => $rule_config->{reject_with} )
    if ( defined $rule_config->{reject_with} );
  push( @iptables_rule, "log-level" => $rule_config->{log_level} )
    if ( defined $rule_config->{log_level} );
  push( @iptables_rule, "log-prefix" => $rule_config->{log_prefix} )
    if ( defined $rule_config->{log_prefix} );
  push( @iptables_rule, "state" => $rule_config->{state} )
    if ( defined $rule_config->{state} );
  push( @iptables_rule, j => uc( $rule_config->{action} ) )
    if ( defined $rule_config->{action} );

  return @iptables_rule;
}

1;
