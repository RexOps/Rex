#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::guestinfo;

use strict;
use warnings;

use Data::Dumper;
use Rex::Logger;
use Rex::Helper::Run;
use Rex::Virtualization::LibVirt::iflist;
use Rex::Commands::Gather;
use Rex::Virtualization::LibVirt::info;

sub execute {
  my ( $class, $vmname ) = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting info of guest: $vmname");

  my $info = Rex::Virtualization::LibVirt::info->execute($vmname);
  if ( $info->{State} eq "shut off" ) {
    return {};
  }

  my $ifs = Rex::Virtualization::LibVirt::iflist->execute($vmname);

  my $got_ip = 0;

  my @ifaces;

  my $command = operating_system_is("Gentoo") ? '/sbin/arp' : '/usr/sbin/arp';

  while ( $got_ip < scalar( keys %{$ifs} ) ) {
    my %arp =
      map { my @x = ( $_ =~ m/\(([^\)]+)\) at ([^\s]+)\s/ ); ( $x[1], $x[0] ) }
      i_run "$command -an";

    for my $if ( keys %{$ifs} ) {
      if ( exists $arp{ $ifs->{$if}->{mac} } && $arp{ $ifs->{$if}->{mac} } ) {
        $got_ip++;
        push @ifaces,
          {
          device => $if,
          ip     => $arp{ $ifs->{$if}->{mac} },
          %{ $ifs->{$if} }
          };
      }
    }

    sleep 1;
  }

  return { network => \@ifaces, };
}

1;
