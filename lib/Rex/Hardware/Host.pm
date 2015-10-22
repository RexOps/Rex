#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Host;

use strict;
use warnings;

# VERSION

use Rex;
use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;

use Rex::Inventory::Bios;

require Rex::Hardware;

sub get {

  my $cache          = Rex::get_cache();
  my $cache_key_name = $cache->gen_key_name("hardware.host");

  if ( $cache->valid($cache_key_name) ) {
    return $cache->get($cache_key_name);
  }

  if ( Rex::is_ssh || $^O !~ m/^MSWin/i ) {

    my $bios = Rex::Inventory::Bios::get();

    my $os = get_operating_system();

    my ( $domain, $hostname );
    if ( $os eq "Windows" ) {
      my @env = i_run("env");
      ($hostname) =
        map { /^COMPUTERNAME=(.*)$/ } split( /\r?\n/, @env );
      ($domain) =
        map { /^USERDOMAIN=(.*)$/ } split( /\r?\n/, @env );
    }
    elsif ( $os eq "NetBSD" || $os eq "OpenBSD" || $os eq 'FreeBSD' ) {
      ( $hostname, $domain ) = split( /\./, i_run("hostname"), 2 );
    }
    elsif ( $os eq "SunOS" ) {
      ($hostname) = map { /^([^\.]+)$/ } i_run("hostname");
      ($domain) = i_run("domainname");
    }
    elsif ( $os eq "OpenWrt" ) {
      ($hostname) = i_run("uname -n");
      ($domain)   = i_run("cat /proc/sys/kernel/domainname");
    }
    else {
      my @out = i_run("hostname -f 2>/dev/null");
      ( $hostname, $domain ) =
        split( /\./, i_run("hostname -f 2>/dev/null"), 2 );

      if ( !$hostname || $hostname eq "" ) {
        Rex::Logger::debug(
          "Error getting hostname and domainname. There is something wrong with your /etc/hosts file."
        );
        $hostname = i_run("hostname");
      }
    }

    my $data = {

      manufacturer => $bios->get_system_information()->get_manufacturer() || "",
      hostname     => $hostname                                           || "",
      domain       => $domain                                             || "",
      operatingsystem  => $os || "",
      operating_system => $os || "",
      operatingsystemrelease   => get_operating_system_version(),
      operating_system_release => get_operating_system_version(),
      kernelname               => [ i_run "uname -s" ]->[0],

    };

    $cache->set( $cache_key_name, $data );

    return $data;

  }
  else {
    return { operatingsystem => $^O, };
  }

}

sub get_operating_system {

  my $cache = Rex::get_cache();
  if ( $cache->valid("hardware.host") ) {
    my $host_cache = $cache->get("hardware.host");
    if ( exists $host_cache->{operatingsystem} ) {
      return $host_cache->{operatingsystem};
    }
  }

  # use lsb_release if available
  my $is_lsb = can_run("lsb_release");

  if ($is_lsb) {
    if ( my $ret = i_run "lsb_release -s -i" ) {
      if ( $ret eq "SUSE LINUX" || $ret eq "openSUSE project" ) {
        $ret = "SuSE";
      }
      return $ret;
    }
  }

  if ( is_dir("c:/") ) {

    # windows
    return "Windows";
  }

  if ( is_file("/etc/system-release") ) {
    my $content = cat "/etc/system-release";
    if ( $content =~ m/Amazon/sm ) {
      return "Amazon";
    }
  }

  if ( is_file("/etc/debian_version") ) {
    return "Debian";
  }

  if ( is_file("/etc/SuSE-release") ) {
    return "SuSE";
  }

  if ( is_file("/etc/mageia-release") ) {
    return "Mageia";
  }

  if ( is_file("/etc/fedora-release") ) {
    return "Fedora";
  }

  if ( is_file("/etc/gentoo-release") ) {
    return "Gentoo";
  }

  if ( is_file("/etc/altlinux-release") ) {
    return "ALT";
  }

  if ( is_file("/etc/redhat-release") ) {
    my $fh      = file_read("/etc/redhat-release");
    my $content = $fh->read_all;
    $fh->close;
    chomp $content;

    if ( $content =~ m/CentOS/ ) {
      return "CentOS";
    }
    elsif ( $content =~ m/Scientific/ ) {
      return "Scientific";
    }
    else {
      return "Redhat";
    }
  }

  if ( is_file("/etc/openwrt_release") ) {
    return "OpenWrt";
  }

  if ( is_file("/etc/arch-release") ) {
    return "Arch";
  }

  my $os_string = i_run("uname -s");
  return $os_string; # return the plain os

}

sub get_operating_system_version {

  my $cache = Rex::get_cache();
  if ( $cache->valid("hardware.host") ) {
    my $host_cache = $cache->get("hardware.host");
    if ( exists $host_cache->{operatingsystemrelease} ) {
      return $host_cache->{operatingsystemrelease};
    }
  }

  my $op = get_operating_system();

  my $is_lsb = can_run("lsb_release");

  # use lsb_release if available
  if ($is_lsb) {
    if ( my $ret = i_run "lsb_release -r -s" ) {
      my $os_check = i_run "lsb_release -d";
      unless ( $os_check =~ m/SUSE\sLinux\sEnterprise\sServer/ ) {
        return $ret;
      }
    }
  }

  if ( $op eq "Debian" ) {

    my $fh      = file_read("/etc/debian_version");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    return $content;

  }
  elsif ( $op eq "Ubuntu" ) {
    my @l = i_run "lsb_release -r -s";
    return $l[0];
  }
  elsif ( lc($op) eq "redhat"
    or lc($op) eq "centos"
    or lc($op) eq "scientific"
    or lc($op) eq "fedora" )
  {

    my $fh      = file_read("/etc/redhat-release");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    $content =~ m/(\d+(\.\d+)?)/;

    return $1;

  }
  elsif ( $op eq "Mageia" ) {
    my $fh      = file_read("/etc/mageia-release");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    $content =~ m/(\d+)/;

    return $1;
  }

  elsif ( $op eq "Gentoo" ) {
    my $fh      = file_read("/etc/gentoo-release");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    return [ split( /\s+/, $content ) ]->[-1];
  }

  elsif ( $op eq "SuSE" ) {

    my ( $version, $release );

    my $fh      = file_read("/etc/SuSE-release");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    if ( $content =~ m/SUSE\sLinux\sEnterprise\sServer/m ) {
      ( $version, $release ) =
        $content =~ m/VERSION\s=\s(\d+)\nPATCHLEVEL\s=\s(\d+)/m;
      $version = "$version.$release";
    }
    else {
      ($version) = $content =~ m/VERSION = (\d+\.\d+)/m;
    }

    return $version;

  }
  elsif ( $op eq "ALT" ) {
    my $fh      = file_read("/etc/altlinux-release");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    $content =~ m/(\d+(\.\d+)*)/;

    return $1;

  }
  elsif ( $op =~ /BSD/ ) {
    my ($version) = map { /(\d+\.\d+)/ } i_run "uname -r";
    return $version;
  }
  elsif ( $op eq "OpenWrt" ) {
    my $fh      = file_read("/etc/openwrt_version");
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    return $content;
  }
  elsif ( $op eq "Arch" ) {
    my $available_updates = i_run "checkupdates";
    if ($available_updates eq "") {
      return "latest";
    } else {
      return "outdated";
    }
  }

  return [ i_run("uname -r") ]->[0];

}

1;
