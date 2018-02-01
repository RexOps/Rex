#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource::firewall::Provider::iptables;

use strict;
use warnings;

# VERSION

use Rex::Commands::Iptables;
use Rex::Helper::Run;
use Data::Dumper;
use base qw(Rex::Resource::firewall::Provider::base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub present {
  my ( $self, $rule_config ) = @_;

  my @iptables_rule = ();

  $rule_config->{dport}      ||= $rule_config->{port};
  $rule_config->{proto}      ||= 'tcp';
  $rule_config->{chain}      ||= 'INPUT';
  $rule_config->{ip_version} ||= -4;

  if ( $rule_config->{source}
    && $rule_config->{source} !~ m/\/(\d+)$/
    && $self->_version()->[0] >= 1
    && $self->_version()->[1] >= 4 )
  {
    $rule_config->{source} .= "/32";
  }

  push( @iptables_rule, t => $rule_config->{table} )
    if ( defined $rule_config->{table} );
  push( @iptables_rule, A => uc( $rule_config->{chain} ) )
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

  if (
    !Rex::Commands::Iptables::_rule_exists(
      $rule_config->{ip_version},
      @iptables_rule
    )
    )
  {
    iptables( $rule_config->{ip_version}, @iptables_rule );
    return 1;
  }

  return 0;
}

sub absent {
  my ( $self, $rule_config ) = @_;

  my @iptables_rule = ();

  $rule_config->{dport} ||= $rule_config->{port};
  $rule_config->{proto} ||= 'tcp';
  $rule_config->{chain} ||= 'INPUT';

  $rule_config->{ip_version} ||= -4;

  if ( $rule_config->{source}
    && $rule_config->{source} !~ m/\/(\d+)$/
    && $self->_version()->[0] >= 1
    && $self->_version()->[1] >= 4 )
  {
    $rule_config->{source} .= "/32";
  }

  push( @iptables_rule, t => $rule_config->{table} )
    if ( defined $rule_config->{table} );
  push( @iptables_rule, D => uc( $rule_config->{chain} ) )
    if ( defined $rule_config->{chain} );
  push( @iptables_rule, s => $rule_config->{source} )
    if ( defined $rule_config->{source} );
  push( @iptables_rule, p => $rule_config->{proto} )
    if ( defined $rule_config->{proto} );
  push( @iptables_rule, m => $rule_config->{proto} )
    if ( defined $rule_config->{proto} );
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

  if (
    Rex::Commands::Iptables::_rule_exists(
      $rule_config->{ip_version},
      @iptables_rule
    )
    )
  {
    iptables( $rule_config->{ip_version}, @iptables_rule );
    return 1;
  }

  return 0;
}

sub _version {
  my ($self) = @_;
  if ( exists $self->{__version__} ) { return $self->{__version__} }

  my $version = i_run "iptables --version", fail_ok => 1;
  $version =~ s/^.*\sv(\d+\.\d+\.\d+)/$1/;

  $self->{__version__} = [ split( /\./, $version ) ];

  Rex::Logger::debug(
    "Got iptables version: " . join( ", ", @{ $self->{__version__} } ) );

  return $self->{__version__};
}

1;
