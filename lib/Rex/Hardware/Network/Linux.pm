#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Hardware::Network::Linux;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Helper::Array;
use Data::Dumper;

sub get_network_devices {

   my @device_list;

   my $command = can_run('ip') ? 'ip link show' : 'ifconfig';

   my @proc_net_dev = grep  { ! /^$/ } map { $1 if /(\S+[^:]+)\:/ } run("cat /proc/net/dev");
   for my $dev (@proc_net_dev) {
      my $output = run("$command $dev");
      if (($output =~ m%link/(ether|ppp) %) or
          ($output =~ m/(Link encap:)?(?:Ethernet|Point-to-Point Protocol)/m)) {
         push(@device_list, $dev);
      }
   }

   @device_list = array_uniq(@device_list);
   return \@device_list;

}

sub get_network_configuration {
   
   my $devices = get_network_devices();

   my $device_info = {};

   my $command = can_run('ip') ? 'ip addr show' : 'ifconfig';

   for my $dev (@{$devices}) {

      my $output = run("LC_ALL=C $command $dev");

      $device_info->{$dev} =
         ($command eq 'ip addr show') ? _parse_ip($output) : _parse_ifconfig($output);

   }

   return $device_info;

}

sub _parse_ifconfig {
   my ($ifconfig) = @_;
   return {
      ip          => [ ( $ifconfig =~ m/inet( addr:| )?(\d+\.\d+\.\d+\.\d+)/ ) ]->[1],
      netmask     => [ ( $ifconfig =~ m/(netmask |Mask:)(\d+\.\d+\.\d+\.\d+)/ ) ]->[1],
      broadcast   => [ ( $ifconfig =~ m/(broadcast |Bcast:)(\d+\.\d+\.\d+\.\d+)/ ) ]->[1],
      mac         => [ ( $ifconfig =~ m/(ether|HWaddr) (..:..:..:..:..:..)/ ) ]->[1],
   };
}

sub _parse_ip {
   my ($ip_lines) = @_;

   # extract all interesting values at once
   my ($mac, $ip, $cidr_prefix, $broadcast) = ($ip_lines =~ m%
         link/.*\ (..:..:..:..:..:..)\ .*
         inet\ (\d+\.\d+\.\d+\.\d+)/(\d+)\ brd\ (\d+\.\d+\.\d+\.\d+)%sx);

   # convert CIDR prefix to dotted decimal notation
   my $binary_mask         = '1' x $cidr_prefix . '0' x (32 - $cidr_prefix);
   my $dotted_decimal_mask = join '.', unpack 'C4', pack 'B32', $binary_mask;
   
   return {
      ip          => $ip,
      netmask     => $dotted_decimal_mask,
      broadcast   => $broadcast,
      mac         => $mac,
   };
}

sub route {

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

sub default_gateway {

   my ($class, $new_default_gw) = @_;

   if($new_default_gw) {
      if(default_gateway()) {
         run "/sbin/route del default";
         if($? != 0) {
            die("Error running route del default");
         }
      }

      run "/sbin/route add default gw $new_default_gw";
      if($? != 0) {
         die("Error route add default");
      }

   }
   else {
      my @route = route();

      my ($default_route) = grep { $_->{"flags"} =~ m/UG/ && ( $_->{"destination"} eq "0.0.0.0" || $_->{"destination"} eq "default" ) } @route;
      return $default_route->{"gateway"} if $default_route;
   }
}

sub netstat {

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


1;
