#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Network::Linux;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Commands::Run;
use Rex::Helper::Array;
use Data::Dumper;

sub get_bridge_devices {
  unless ( can_run("brctl") ) {
    Rex::Logger::debug("No brctl available");
    return {};
  }

  local $/ = "\n";
  my @lines = i_run 'brctl show', fail_ok => 1;
  chomp @lines;
  shift @lines;

  my $current_bridge;
  my $data = {};
  for my $line (@lines) {
    if ( $line =~ m/^[A-Za-z0-9_.]+/ ) {
      my ( $br, $br_id, $stp, $dev ) = split( /\s+/, $line );
      $current_bridge = $br;
      $data->{$br}->{stp} = 0;
      push @{ $data->{$br}->{devices} }, $dev;
      next;
    }

    my ($dev) = ( $line =~ m/([a-zA-Z0-9_.]+)$/ );
    if ($dev) {
      push @{ $data->{$current_bridge}->{devices} }, $dev;
    }
  }

  return $data;
}

sub get_network_devices {

  my $command = can_run('ip') ? 'ip addr show' : 'ifconfig -a';
  my @output  = i_run( "$command", fail_ok => 1 );

  my $devices =
    ( $command eq 'ip addr show' )
    ? _parse_ip(@output)
    : _parse_ifconfig(@output);
  my @device_list = keys %{$devices};

  return \@device_list;
}

sub get_network_configuration {

  my $device_info = {};

  my $command = can_run('ip') ? 'ip addr show' : 'ifconfig -a';
  my @output  = i_run( "$command", fail_ok => 1 );

  my $br_data = get_bridge_devices();

  my $data =
    ( $command eq 'ip addr show' )
    ? _parse_ip(@output)
    : _parse_ifconfig(@output);

  for my $dev ( keys %{$data} ) {
    if ( exists $br_data->{$dev} ) {
      $data->{$dev}->{is_bridge} = 1;
    }
    else {
      $data->{$dev}->{is_bridge} = 0;
    }
  }

  return $data;
}

sub _parse_ifconfig {
  my (@ifconfig) = @_;

  my $dev = {};

  my $cur_dev;
  for my $line (@ifconfig) {
    if ( $line =~ m/^([a-zA-Z0-9:\._]+)/ ) {
      my $new_dev = $1;
      $new_dev = substr( $new_dev, 0, -1 ) if ( $new_dev =~ m/:$/ );

      if ( $cur_dev && $cur_dev ne $new_dev ) {
        $cur_dev = $new_dev;
      }

      if ( !$cur_dev ) {
        $cur_dev = $new_dev;
      }

      $dev->{$cur_dev}->{mac}       = "";
      $dev->{$cur_dev}->{ip}        = "";
      $dev->{$cur_dev}->{netmask}   = "";
      $dev->{$cur_dev}->{broadcast} = "";

    }

    if ( $line =~ m/(ether|HWaddr) (..:..:..:..:..:..)/ ) {
      $dev->{$cur_dev}->{mac} = $2;
    }

    if ( $line =~ m/inet( addr:| )?(\d+\.\d+\.\d+\.\d+)/ ) {
      $dev->{$cur_dev}->{ip} = $2;
    }

    if ( $line =~ m/(netmask |Mask:)(\d+\.\d+\.\d+\.\d+)/ ) {
      $dev->{$cur_dev}->{netmask} = $2;
    }

    if ( $line =~ m/(broadcast |Bcast:)(\d+\.\d+\.\d+\.\d+)/ ) {
      $dev->{$cur_dev}->{broadcast} = $2;
    }

  }

  return $dev;

}

sub _parse_ip {
  my (@ip_lines) = @_;

  my $dev = {};

  my $cur_dev;
  for my $line (@ip_lines) {
    if ( $line =~ m/^\d+:\s*([^\s]+):/ ) {
      my $new_dev = $1;

      if ( $cur_dev && $cur_dev ne $new_dev ) {
        $cur_dev = $new_dev;
      }

      if ( !$cur_dev ) {
        $cur_dev = $new_dev;
      }

      $dev->{$cur_dev}->{ip}        = "";
      $dev->{$cur_dev}->{mac}       = "";
      $dev->{$cur_dev}->{netmask}   = "";
      $dev->{$cur_dev}->{broadcast} = "";

      next;
    }

    if ( $line =~ m/^\s*link\/ether (..:..:..:..:..:..)/ ) {
      $dev->{$cur_dev}->{mac} = $1;
    }

    # loopback
    #    if ( $line =~ m/^\s*inet (\d+\.\d+\.\d+\.\d+)\/(\d+) scope host lo/ ) {
    #      $dev->{$cur_dev}->{ip}      = $1;
    #      $dev->{$cur_dev}->{netmask} = _convert_cidr_prefix($2);
    #    }

    my $sec_i = 1;
    if ( $line =~
      m/^\s*inet (\d+\.\d+\.\d+\.\d+)\/(\d+) (brd (\d+\.\d+\.\d+\.\d+) )?scope ([^\s]+) (\w+\s)?(.+?)$/
      )
    {
      my $ip          = $1;
      my $cidr_prefix = $2;
      my $broadcast   = $4 || '';
      my $scope       = $5;
      my $dev_name    = $7 || $6;
      chomp $dev_name;

      if ( $scope eq "global" && $dev_name ne $cur_dev ) {

        # this is an alias
        $dev->{$dev_name}->{ip}        = $ip;
        $dev->{$dev_name}->{broadcast} = $broadcast;
        $dev->{$dev_name}->{netmask}   = _convert_cidr_prefix($cidr_prefix);
        $dev->{$dev_name}->{mac}       = $dev->{$cur_dev}->{mac};
      }
      elsif ( $dev_name eq $cur_dev && $dev->{$cur_dev}->{ip} ) {

        # there is already an ip address, so this must be a secondary
        $dev->{"${dev_name}_${sec_i}"}->{ip}        = $ip;
        $dev->{"${dev_name}_${sec_i}"}->{broadcast} = $broadcast;
        $dev->{"${dev_name}_${sec_i}"}->{netmask} =
          _convert_cidr_prefix($cidr_prefix);
        $dev->{"${dev_name}_${sec_i}"}->{mac} = $dev->{$cur_dev}->{mac};
        $sec_i++;
      }
      else {
        $dev->{$cur_dev}->{ip}        = $ip;
        $dev->{$cur_dev}->{broadcast} = $broadcast;
        $dev->{$cur_dev}->{netmask}   = _convert_cidr_prefix($cidr_prefix);
      }
    }

    # ppp
    if ( $line =~
      m/^\s*inet (\d+\.\d+\.\d+\.\d+) peer (\d+\.\d+\.\d+\.\d+)\/(\d+)/ )
    {
      $dev->{$cur_dev}->{ip}      = $1;
      $dev->{$cur_dev}->{netmask} = _convert_cidr_prefix($3);
    }
  }

  return $dev;
}

sub route {

  my @ret = ();

  my @route = i_run "netstat -nr", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running netstat");
  }

  shift @route;
  shift @route; # remove first 2 lines

  for my $route_entry (@route) {
    my ( $dest, $gw, $genmask, $flags, $mss, $window, $irtt, $iface ) =
      split( /\s+/, $route_entry, 8 );
    push(
      @ret,
      {
        destination => $dest,
        gateway     => $gw,
        genmask     => $genmask,
        flags       => $flags,
        mss         => $mss,
        irtt        => $irtt,
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
      i_run "/sbin/route del default", fail_ok => 1;
      if ( $? != 0 ) {
        die("Error running route del default");
      }
    }

    i_run "/sbin/route add default gw $new_default_gw", fail_ok => 1;
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
  my @netstat = i_run "netstat -nap", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running netstat");
  }
  my ( $in_inet, $in_unix, $in_unknown ) = ( 0, 0, 0 );
  for my $line (@netstat) {
    if ( $in_inet == 1 ) { ++$in_inet; next; }
    if ( $in_unix == 1 ) { ++$in_unix; next; }
    if ( $line =~ m/^Active Internet/ ) {
      $in_inet    = 1;
      $in_unix    = 0;
      $in_unknown = 0;
      next;
    }

    if ( $line =~ m/^Active UNIX/ ) {
      $in_inet    = 0;
      $in_unix    = 1;
      $in_unknown = 0;
      next;
    }

    if ( $line =~ m/^Active/ ) {
      $in_inet    = 0;
      $in_unix    = 0;
      $in_unknown = 1;
      next;
    }

    if ($in_unknown) {
      next;
    }

    if ($in_inet) {
      my ( $proto, $recvq, $sendq, $local_addr, $foreign_addr, $state,
        $pid_cmd );

      unless ( $line =~ m/^udp/ ) {

        # no state
        ( $proto, $recvq, $sendq, $local_addr, $foreign_addr, $state, $pid_cmd )
          = split( /\s+/, $line, 7 );
      }
      else {
        ( $proto, $recvq, $sendq, $local_addr, $foreign_addr, $pid_cmd ) =
          split( /\s+/, $line, 6 );
      }

      $pid_cmd ||= "";

      my ( $pid, $cmd ) = split( /\//, $pid_cmd, 2 );
      if ( $pid =~ m/^-/ ) {
        $pid = "";
      }
      $cmd   ||= "";
      $state ||= "";

      $cmd =~ s/\s+$//;

      push(
        @ret,
        {
          proto        => $proto,
          recvq        => $recvq,
          sendq        => $sendq,
          local_addr   => $local_addr,
          foreign_addr => $foreign_addr,
          state        => $state,
          pid          => $pid,
          command      => $cmd,
        }
      );
      next;
    }

    if ($in_unix) {

      my ( $proto, $refcnt, $flags, $type, $state, $inode, $pid, $cmd, $path );

      if ( $line =~
        m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+(\d+)\/([^\s]+)\s+(.*)$/i
        )
      {
        ( $proto, $refcnt, $flags, $type, $state, $inode, $pid, $cmd, $path ) =
          ( $line =~
            m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+(\d+)\/([^\s]+)\s+(.*)$/i
          );
      }
      else {
        ( $proto, $refcnt, $flags, $type, $state, $inode, $path ) =
          ( $line =~
            m/^([a-z]+)\s+(\d+)\s+\[([^\]]+)\]\s+([a-z]+)\s+([a-z]+)?\s+(\d+)\s+\-\s+(.*)$/i
          );

        $pid = "";
        $cmd = "";
      }

      $state =~ s/^\s|\s$//g if ($state);
      $flags =~ s/\s+$//     if ($flags);
      $cmd   =~ s/\s+$//;

      my $data = {
        proto   => $proto,
        refcnt  => $refcnt,
        flags   => $flags,
        type    => $type,
        state   => $state,
        inode   => $inode,
        pid     => $pid,
        command => $cmd,
        path    => $path,
      };

      push( @ret, $data );
    }

  }

  return @ret;

}

sub _convert_cidr_prefix {
  my ($cidr_prefix) = @_;

  # convert CIDR prefix to dotted decimal notation
  my $binary_mask = '1' x $cidr_prefix . '0' x ( 32 - $cidr_prefix );
  my $dotted_decimal_mask = join '.', unpack 'C4', pack 'B32', $binary_mask;

  return $dotted_decimal_mask;
}

1;
