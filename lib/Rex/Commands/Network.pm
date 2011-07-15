#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Network - Network Module

=head1 DESCRIPTION

With this module you can get information of the routing table, current network connections, open ports, ...

=head1 SYNOPSIS

 use Rex::Commands::Network;
    
 my @routes = route;
 print Dumper(\@routes);
    
 my $default_gw = default_gateway;
 default_gateway "192.168.2.1";
     
 my @netstat = netstat;
 my @tcp_connections = grep { $_->{"proto"} eq "tcp" } netstat;

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Network;

use strict;
use warnings;

require Exporter;
use Rex::Commands::Run;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(route default_gateway netstat);

=item route

Get routing information

=cut
sub route {

   my @ret = ();

   my @route = run "netstat -nr";  
   shift @route; shift @route; # remove first 2 lines

   for my $route_entry (@route) {
      my ($dest, $gw, $genmask, $flags, $mss, $window, $irtt, $iface) = split(/\s+/, $route_entry, 8);
      push(@ret, {
         destination => $dest,
         gateway     => $gw,
         genmask     => $genmask,
         flags       => $flags,
         mss         => $mss,
         irtt        => $irtt,
         iface       => $iface,
      });
   }

   return @ret;

}

=item default_gateway([$default_gw])

Get or set the default gateway.

=cut
sub default_gateway {
   my ($new_default_gw) = @_;

   if($new_default_gw) {
      if(default_gateway()) {
         run "route del default";
      }

      run "route add default gw $new_default_gw";
   }
   else {
      my @route = route();

      my ($default_route) = grep { $_->{"flags"} =~ m/UG/ && $_->{"destination"} eq "0.0.0.0" } @route;
      return $default_route->{"gateway"} if $default_route;
   }
}

=item netstat

Get network connection information

=cut
sub netstat {

   my @ret;

   my @netstat = run "netstat -nap";
   my ($in_inet, $in_unix) = (0, 0);
   for my $line (@netstat) {
      if($in_inet == 1) { ++$in_inet; next; }
      if($in_unix == 1) { ++$in_unix; next; }
      if($line =~ m/^Active Internet/) {
         $in_inet = 1;
         next;
      }

      if($line =~ m/^Active UNIX/) {
         $in_inet = 0;
         $in_unix = 1;
         next;
      }

      if($in_inet) {
         my ($proto, $recvq, $sendq, $local_addr, $foreign_addr, $state, $pid_cmd) = split(/\s+/, $line, 7);
         my ($pid, $cmd) = split(/\//, $pid_cmd, 2);
         push(@ret, {
            proto        => $proto,
            recvq        => $recvq,
            sendq        => $sendq,
            local_addr   => $local_addr,
            foreign_addr => $foreign_addr,
            state        => $state,
            pid          => $pid,
            command      => $cmd,
         });
         next;
      }

      if($in_unix) {
         my ($proto, $refcnt, $flags, $type, $state, $inode, $pid, $cmd, $path) 
            = ($line =~ m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+(\d+)\/([^\s]+)\s+(.*)$/i);
         $state =~ s/^\s|\s$//g if ($state);

         push(@ret, {
            proto        => $proto,
            refcnt       => $refcnt,
            flags        => $flags,
            type         => $type,
            state        => $state,
            inode        => $inode,
            pid          => $pid,
            command      => $cmd,
            path         => $path,
         });
      }

   }

   return @ret;

}

=back

=cut

1;
