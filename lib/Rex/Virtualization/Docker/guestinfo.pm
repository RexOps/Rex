#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::guestinfo;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;
use Rex::Logger;
use Rex::Helper::Run;
use Rex::Virtualization::Docker::status;
use Rex::Virtualization::Docker::info;

sub execute {
  my ( $class, $vmname ) = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting info of guest: $vmname");

  my $status = Rex::Virtualization::Docker::status->execute($vmname);
  if ( $status eq "stopped" ) {
    Rex::Logger::debug("VM is not running, no guestinfo available.");
    return {};
  }

  my @netinfo;
  my %redir_ports;

  my $data = Rex::Virtualization::Docker::info->execute($vmname);

  for my $redir ( keys %{ $data->{NetworkSettings}->{Ports} } ) {
    my ( $port, $proto ) = split( /\//, $redir );
    for my $redir_t ( @{ $data->{NetworkSettings}->{Ports}->{$redir} } ) {
      push @{ $redir_ports{$proto}->{$port} },
        {
        ip   => $redir_t->{HostIp},
        port => $redir_t->{HostPort},
        };
    }
  }

  for my $net ( keys %{ $data->{NetworkSettings}->{Networks} } ) {
    push @netinfo,
      {
      ip  => $data->{NetworkSettings}->{Networks}->{$net}->{IPAddress},
      mac => $data->{NetworkSettings}->{Networks}->{$net}->{MacAddress},
      };
  }

  return {
    redirects => \%redir_ports,
    network   => \@netinfo,
  };

}

1;
