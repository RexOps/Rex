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

use strict;
use warnings;

# VERSION

use Data::Dumper;

use Rex -minimal;

use Rex::Commands::Gather;
use Rex::Resource::Common;

use Carp;

my $__provider = { default => "Rex::Resource::firewall::Provider::iptables", };

=item firewall($name, %params)

=cut

resource "firewall", {
  export      => 1,
  params_list => [
    name => {
      isa     => 'Str',
      default => sub { shift }
    },
    ensure => {
      isa     => 'Str',
      default => sub { "present" }
    },
    action      => { isa => 'Str | Undef', default => undef },
    proto       => { isa => 'Str | Undef', default => "tcp" },
    source      => { isa => 'Str | Undef', default => undef },
    destination => { isa => 'Str | Undef', default => undef },
    port        => { isa => 'Int | Undef', default => undef },
    source      => { isa => 'Str | Undef', default => undef },
    app         => { isa => 'Str | Undef', default => undef },
    sport       => { isa => 'Int | Undef', default => undef },
    dport       => {
      isa     => 'Int | Undef',
      default => sub { my ( $name, %p ) = @_; return $p{port}; },
    },
    dapp        => { isa => 'Str | Undef',      default => undef },
    tcp_flags   => { isa => 'ArrayRef | Undef', default => undef },
    chain       => { isa => 'Str | Undef',      default => "INPUT" },
    table       => { isa => 'Str | Undef',      default => undef },
    iniface     => { isa => 'Str | Undef',      default => undef },
    outiface    => { isa => 'Str | Undef',      default => undef },
    reject_with => { isa => 'Str | Undef',      default => undef },
    logging     => { isa => 'Str | Undef',      default => undef },
    log         => { isa => 'Str | Undef',      default => undef },
    log_level   => { isa => 'Str | Undef',      default => undef },
    log_prefix  => { isa => 'Str | Undef',      default => undef },
    state       => { isa => 'Str | Undef',      default => undef },
    ip_version  => { isa => 'Str | Undef',      default => "-4" },
  ],
  },
  sub {
  my ( $name, %args ) = @_;

  my $provider = resolve_resource_provider( $args{provider}
      || case ( lc(operating_system), $__provider ) );

  # TODO define provider type automatically.
  $provider->require;
  my $provider_o =
    $provider->new( type => "firewall", name => $name, config => \%args );
  $provider_o->process;
  };

=back

=cut

1;
