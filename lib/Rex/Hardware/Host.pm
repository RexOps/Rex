#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Hardware::Host;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use English qw(-no_match_vars);
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

  my $bios = Rex::Inventory::Bios::get();

  my $os = get_operating_system();

  my ( $domain, $hostname );
  if ( $os eq "Windows" ) {
    my @env = i_run('set');
    ($hostname) = map { /^COMPUTERNAME=(.*)$/ } @env;
    ($domain)   = map { /^USERDOMAIN=(.*)$/ } @env;
  }
  elsif ( $os eq "NetBSD" || $os eq "OpenBSD" || $os eq 'FreeBSD' ) {
    ( $hostname, $domain ) =
      split( /\./, ( eval { i_run("hostname") } || "unknown.nodomain" ), 2 );
  }
  elsif ( $os eq "SunOS" ) {
    ($hostname) =
      map { /^([^\.]+)$/ } ( eval { i_run("hostname"); } || "unknown" );
    ($domain) = eval { i_run("domainname"); } || ("nodomain");
  }
  elsif ( $os eq "OpenWrt" ) {
    ($hostname) = eval { i_run("uname -n"); } || ("unknown");
    ($domain) =
      eval { i_run("cat /proc/sys/kernel/domainname"); } || ("unknown");
  }
  else {
    my @out = i_run "hostname -f 2>/dev/null", fail_ok => 1;

    if ( $? == 0 ) {
      ( $hostname, $domain ) = split( /\./, $out[0], 2 );
    }
    else {
      Rex::Logger::debug(
        "Error getting hostname and domainname. There is something wrong with your /etc/hosts file."
      );
      ($hostname) = eval { i_run("hostname -s"); } || ("unknown");
      ($domain)   = eval { i_run("hostname -d"); } || ("nodomain");
    }
  }

  my $kernelname = q();

  if ( can_run('uname') ) {
    $kernelname = i_run 'uname -s';
  }

  my $operating_system_version = get_operating_system_version();

  my $data = {

    manufacturer => $bios->get_system_information()->get_manufacturer() || "",
    hostname     => $hostname                                           || "",
    domain       => $domain                                             || "",
    operatingsystem          => $os                                     || "",
    operating_system         => $os                                     || "",
    operatingsystemrelease   => $operating_system_version,
    operating_system_release => $operating_system_version,
    kernelname               => $kernelname,

  };

  $cache->set( $cache_key_name, $data );

  return $data;

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
      if ( $ret =~ m/SUSE/i ) {
        $ret = "SuSE";
      }
      elsif ( $ret eq "ManjaroLinux" ) {
        $ret = "Manjaro";
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

  if ( is_file("/etc/SuSE-release") or is_file("/etc/SUSE-brand") ) {
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

  if ( is_file("/etc/manjaro-release") ) {
    return "Manjaro";
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
      unless ( $os_check =~ m/SUSE\sLinux\sEnterprise/ ) {
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
    my @l = i_run "lsb_release -r -s", fail_ok => 1;
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

    my $release_file;
    if ( is_file("/etc/os-release") ) {
      $release_file = "/etc/os-release";
    }
    else {
      $release_file = "/etc/SuSE-release";
    }

    my $fh      = file_read($release_file);
    my $content = $fh->read_all;
    $fh->close;

    chomp $content;

    if ( $content =~ m/VERSION_ID/m ) {
      ($version) = $content =~ m/VERSION_ID="(\d+(?:\.)?\d+)"/m;
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
    my $available_updates = i_run "checkupdates", fail_ok => 1;
    if ( $available_updates eq "" ) {
      return "latest";
    }
    else {
      return "outdated";
    }
  }
  elsif ( $op eq 'Windows' ) {
    my $version = i_run 'ver', fail_ok => 1;

    if ( $CHILD_ERROR == 0 ) {
      return $version;
    }
  }

  return [ i_run("uname -r") ]->[0];

}

1;
