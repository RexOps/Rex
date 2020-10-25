#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network::Solaris;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Helper::Array;

sub get_network_devices {

  my @device_list = map { /^([a-z0-9]+)\:/i } i_run "ifconfig -a";

  @device_list = array_uniq(@device_list);
  return \@device_list;

}

sub get_network_configuration {

  my $devices = get_network_devices();

  my $device_info = {};

  for my $dev ( @{$devices} ) {

    my $ifconfig = i_run("ifconfig $dev");

    $device_info->{$dev} = {
      ip      => [ ( $ifconfig =~ m/inet (\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
      netmask => [ ( $ifconfig =~ m/(netmask 0x|netmask )([a-f0-9]+)/ ) ]->[1],
      broadcast => [ ( $ifconfig =~ m/broadcast (\d+\.\d+\.\d+\.\d+)/ ) ]->[0],
      mac       => [
        ( $ifconfig =~ m/(ether|address:|lladdr) (..?:..?:..?:..?:..?:..?)/ )
      ]->[1],
      is_bridge => 0,
    };

  }

  return $device_info;

}

sub route {

  my @ret = ();

  my @route = i_run "netstat -nr", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running netstat");
  }

  shift @route;
  shift @route; # remove first 2 lines
  shift @route;
  shift @route; # remove first 2 lines

  for my $route_entry (@route) {

    if ( $route_entry =~ m/^$/
      || $route_entry =~ m/^Routing Table:/
      || $route_entry =~ m/^\s+Destination/
      || $route_entry =~ m/^---------/ )
    {
      next;
    }

    my ( $dest, $gw, $flags, $ref, $use, $iface ) =
      split( /\s+/, $route_entry, 6 );
    push(
      @ret,
      {
        destination => $dest,
        gateway     => $gw,
        flags       => $flags,
        ref         => $ref,
        use         => $use,
        iface       => $iface,
      }
    );
  }

  return @ret;

}

sub default_gateway {

  my ( $class, $new_default_gw ) = @_;

  if ($new_default_gw) {
    if ( default_gateway() ) {
      i_run "route delete default " . default_gateway(), fail_ok => 1;
      if ( $? != 0 ) {
        die("Error running route del default");
      }
    }

    i_run "route add default $new_default_gw", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error route add default");
    }

  }
  else {
    my @route = route();

    my ($default_route) = grep {
      $_->{"flags"} =~ m/UG/
        && ( $_->{"destination"} eq "0.0.0.0"
        || $_->{"destination"} eq "default" )
    } @route;
    return $default_route->{"gateway"} if $default_route;
  }
}

sub netstat {

  my @ret;
  my @netstat = i_run "netstat -na -f inet -f inet6", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running netstat");
  }

  my ( $proto, $udp_v4, $udp_v6, $tcp_v4, $tcp_v6, $sctp );
  for my $line (@netstat) {

    if ( $line =~ m/^$/
      || $line =~ m/^\s+Local/
      || $line =~ m/^--------/ )
    {
      next;
    }

    if ( $line =~ m/^UDP: IPv4/ ) {
      $udp_v4 = 0;
      $udp_v6 = 0;
      $tcp_v4 = 0;
      $tcp_v6 = 0;
      $sctp   = 0;
      $udp_v4 = 1;
      $proto  = "udp";
      next;
    }

    if ( $line =~ m/^UDP: IPv6/ ) {
      $udp_v4 = 0;
      $udp_v6 = 0;
      $tcp_v4 = 0;
      $tcp_v6 = 0;
      $sctp   = 0;
      $udp_v6 = 1;
      $proto  = "udp6";
      next;
    }

    if ( $line =~ m/^TCP: IPv4/ ) {
      $udp_v4 = 0;
      $udp_v6 = 0;
      $tcp_v4 = 0;
      $tcp_v6 = 0;
      $sctp   = 0;
      $tcp_v4 = 1;
      $proto  = "tcp";
      next;
    }

    if ( $line =~ m/^TCP: IPv6/ ) {
      $udp_v4 = 0;
      $udp_v6 = 0;
      $tcp_v4 = 0;
      $tcp_v6 = 0;
      $sctp   = 0;
      $tcp_v6 = 1;
      $proto  = "tcp6";
      next;
    }

    if ( $line =~ m/^SCTP:/ ) {
      $udp_v4 = 0;
      $udp_v6 = 0;
      $tcp_v4 = 0;
      $tcp_v6 = 0;
      $sctp   = 0;
      $sctp   = 1;
      $proto  = "sctp";
      next;
    }

    $line =~ s/^\s+//;

    if ($udp_v4) {
      $line = " $line";
      my ( $local_addr, $remote_addr, $state ) =
        ( $line =~ m/\s+?([^\s]+)\s+([^\s]+)?\s+([^\s]+)/ );
      push(
        @ret,
        {
          proto        => $proto,
          local_addr   => $local_addr,
          foreign_addr => $remote_addr,
          state        => $state,
        }
      );
      next;
    }

    if ($udp_v6) {
      $line = " $line";
      my ( $local_addr, $remote_addr, $state, $if ) =
        ( $line =~ m/\s+?([^\s]+)\s+([^\s]+)?\s+([^\s]+)\s+([^\s]+)/ );
      push(
        @ret,
        {
          proto        => $proto,
          local_addr   => $local_addr,
          foreign_addr => $remote_addr,
          state        => $state,
          if           => $if,
        }
      );
      next;
    }

    if ($tcp_v4) {
      my ( $local_addr, $remote_addr, $swind, $sendq, $rwind, $recvq, $state )
        = split( /\s+/, $line, 7 );
      push(
        @ret,
        {
          proto        => $proto,
          local_addr   => $local_addr,
          foreign_addr => $remote_addr,
          swind        => $swind,
          sendq        => $sendq,
          rwind        => $rwind,
          recvq        => $recvq,
          state        => $state,
        }
      );
      next;
    }

    if ($tcp_v6) {
      my ( $local_addr, $remote_addr, $swind, $sendq, $rwind, $recvq, $state,
        $if )
        = split( /\s+/, $line, 8 );
      push(
        @ret,
        {
          proto        => $proto,
          local_addr   => $local_addr,
          foreign_addr => $remote_addr,
          swind        => $swind,
          sendq        => $sendq,
          rwind        => $rwind,
          recvq        => $recvq,
          state        => $state,
          if           => $if,
        }
      );
      next;
    }

    if ($sctp) {
      my ( $local_addr, $remote_addr, $swind, $sendq, $rwind, $recvq, $strs,
        $state )
        = split( /\s+/, $line, 8 );
      push(
        @ret,
        {
          proto        => $proto,
          local_addr   => $local_addr,
          foreign_addr => $remote_addr,
          swind        => $swind,
          sendq        => $sendq,
          rwind        => $rwind,
          recvq        => $recvq,
          state        => $state,
          strsio       => $strs,
        }
      );
      next;
    }

  }

  @netstat = i_run "netstat -na -f unix", fail_ok => 1;
  shift @netstat;
  shift @netstat;
  shift @netstat;

  for my $line (@netstat) {
    my ( $address, $type, $vnode, $conn, $local_addr, $remote_addr ) =
      split( /\s+/, $line, 7 );

    my $data = {
      proto   => "unix",
      address => $address,
      type    => $type,
      nvnode  => $vnode,
      conn    => $conn,
      path    => $local_addr,
    };

    push( @ret, $data );

  }

  return @ret;

}

1;
