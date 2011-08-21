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
use Rex::Commands::Gather;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(route default_gateway netstat);

=item route

Get routing information

=cut
sub route {

   my $os = get_operating_system();
   
   if($os =~ m/BSD/) {
      Rex::Logger::info("route not supported under BSD");
      return;
   }

   my @ret = ();

   my @route = run "netstat -nr";  
   if($? != 0) {
      die("Error running netstat");
   }
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

   my $os = get_operating_system();
   
   if($os =~ m/BSD/) {
      Rex::Logger::info("default_gateway not supported under BSD");
      return;
   }

   my ($new_default_gw) = @_;

   if($new_default_gw) {
      if(default_gateway()) {
         run "route del default";
         if($? != 0) {
            die("Error running route del default");
         }
      }

      run "route add default gw $new_default_gw";
      if($? != 0) {
         die("Error route add default");
      }

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

   my $os = get_operating_system();
   
   if($os =~ m/BSD/) {
      Rex::Logger::info("netstat not supported under BSD");
      return;
   }

   my @ret;

   my @netstat = run "netstat -nap";
   if($? != 0) {
      die("Error running netstat");
   }
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
         my ($proto, $recvq, $sendq, $local_addr, $foreign_addr, $state, $pid_cmd);

         unless($line =~ m/^udp/) {
            # no state
            ($proto, $recvq, $sendq, $local_addr, $foreign_addr, $state, $pid_cmd) = split(/\s+/, $line, 7);
         }
         else {
            ($proto, $recvq, $sendq, $local_addr, $foreign_addr, $pid_cmd) = split(/\s+/, $line, 6);
         }

         $pid_cmd ||= "";

         my ($pid, $cmd) = split(/\//, $pid_cmd, 2);
         if($pid =~ m/^-/) {
            $pid = "";
         }
         $cmd   ||= "";
         $state ||= "";

         $cmd =~ s/\s+$//;

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

         my ($proto, $refcnt, $flags, $type, $state, $inode, $pid, $cmd, $path);

         if($line =~ m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+(\d+)\/([^\s]+)\s+(.*)$/i) {
            ($proto, $refcnt, $flags, $type, $state, $inode, $pid, $cmd, $path) 
               = ($line =~ m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+(\d+)\/([^\s]+)\s+(.*)$/i);
         }
         else {
            ($proto, $refcnt, $flags, $type, $state, $inode, $path) 
               = ($line =~ m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+\-\s+(.*)$/i);

            $pid = "";
            $cmd = "";
         }


         $state =~ s/^\s|\s$//g if ($state);
         $flags =~ s/\s+$//;
         $cmd =~ s/\s+$//;

         my $data = {
            proto        => $proto,
            refcnt       => $refcnt,
            flags        => $flags,
            type         => $type,
            state        => $state,
            inode        => $inode,
            pid          => $pid,
            command      => $cmd,
            path         => $path,
         };

         push(@ret, $data);
      }

   }

   return @ret;

}

=back

=cut

1;
