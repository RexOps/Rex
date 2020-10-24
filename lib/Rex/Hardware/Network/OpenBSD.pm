#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network::OpenBSD;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Helper::Array;
use Rex::Hardware::Network::FreeBSD;

sub get_network_devices {

  return Rex::Hardware::Network::FreeBSD::get_network_devices();

}

sub get_network_configuration {

  return Rex::Hardware::Network::FreeBSD::get_network_configuration();

}

sub route {

  my @route = i_run "netstat -nr", fail_ok => 1;
  my @ret;
  if ( $? != 0 ) {
    die("Error running netstat");
  }

  my ( $in_v6, $in_v4 );
  for my $route_entry (@route) {
    if ( $route_entry eq "Internet:" ) {
      $in_v4 = 1;
      next;
    }

    if ( $route_entry eq "Internet6:" ) {
      $in_v6 = 1;
      $in_v4 = 0;
      next;
    }

    if ( $route_entry =~ m/^$/ ) {
      $in_v6 = 0;
      $in_v4 = 0;
      next;
    }

    if ( $route_entry =~ m/^AppleTalk/ ) {

      # kein appletalk ...
      next;
    }

    if ( $route_entry =~ m/^Destination/ ) {
      next;
    }

    if ($in_v4) {
      my ( $dest, $gw, $flags, $refs, $use, $mtu, $prio, $netif ) =
        split( /\s+/, $route_entry, 8 );
      push(
        @ret,
        {
          destination => $dest,
          gateway     => $gw,
          flags       => $flags,
          iface       => $netif,
          refs        => $refs,
          mtu         => $mtu,
          priority    => $prio,
        }
      );

      next;
    }

    if ($in_v6) {
      my ( $dest, $gw, $flags, $refs, $use, $mtu, $prio, $netif ) =
        split( /\s+/, $route_entry, 8 );
      push(
        @ret,
        {
          destination => $dest,
          gateway     => $gw,
          flags       => $flags,
          iface       => $netif,
          refs        => $refs,
          mtu         => $mtu,
          priority    => $prio,
        }
      );
    }

  }

  return @ret;

}

sub default_gateway {

  my ( $class, $new_default_gw ) = @_;

  if ($new_default_gw) {
    if ( default_gateway() ) {
      i_run "route delete default", fail_ok => 1;
      if ( $? != 0 ) {
        die("Error running route delete default");
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
  my @netstat = i_run "netstat -na", fail_ok => 1;

  if ( $? != 0 ) {
    die("Error running netstat");
  }

  shift @netstat;

  my ( $in_inet, $in_unix ) = ( 0, 0 );

  for my $line (@netstat) {
    if ( $line =~ m/^Proto\s*Recv/ ) {
      $in_inet = 1;
      next;
    }

    if ( $line =~ m/^Active Internet/ ) {
      next;
    }

    if ( $line =~ m/^Active UNIX/ ) {
      $in_inet = 0;
      $in_unix = 1;
      next;
    }

    if ( $line =~ m/^Address\s*Type/ ) {
      next;
    }

    if ($in_inet) {
      my ( $proto, $recvq, $sendq, $local_addr, $foreign_addr, $state ) =
        split( /\s+/, $line, 6 );
      if ( $proto eq "tcp4" ) { $proto = "tcp"; }
      push(
        @ret,
        {
          proto        => $proto,
          recvq        => $recvq,
          sendq        => $sendq,
          local_addr   => $local_addr,
          foreign_addr => $foreign_addr,
          state        => $state,
        }
      );
      next;
    }

    if ($in_unix) {
      my (
        $address, $type, $recvq,   $sendq, $inode,
        $conn,    $refs, $nextref, $addr
      ) = split( /\s+/, $line, 9 );
      push(
        @ret,
        {
          proto   => "unix",
          address => $address,
          refcnt  => $refs,
          type    => $type,
          inode   => $inode,
          path    => $addr,
          recvq   => $recvq,
          sendq   => $sendq,
          conn    => $conn,
          nextref => $nextref,
        }
      );

      next;
    }
  }

  return @ret;

}

1;

1;
