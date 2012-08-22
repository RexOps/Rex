#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Host;

use strict;
use warnings;

use Rex;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;

use Rex::Inventory::Bios;

sub get {

   if(Rex::is_ssh || $^O !~ m/^MSWin/i) {

      my $dmi = Rex::get_cache()->can_run("dmidecode");

      unless($dmi) {
         Rex::Logger::debug("Please install dmidecode on the target system.");
      }

      my $bios = Rex::Inventory::Bios::get();

      my $os = Rex::get_cache()->call_sub("Rex::Hardware::Host", "get_operating_system");

      my ($domain, $hostname);
      if($os eq "NetBSD" || $os eq "OpenBSD") {
         ($hostname) = grep { $_=$1 if /^([^\.]+)\.(.*)$/ } Rex::get_cache()->run("LC_ALL=C hostname");
         ($domain) = grep { $_=$2 if /^([^\.]+)\.(.*)$/ } Rex::get_cache()->run("LC_ALL=C hostname");
      }
      elsif($os eq "SunOS") {
         ($hostname) = grep { $_=$1 if /^([^\.]+)$/ } Rex::get_cache()->run("LC_ALL=C hostname");
         ($domain) = run("LC_ALL=C domainname");
      }
      else {
         ($hostname) = grep { $_=$1 if /^([^\.]+)\.(.*)$/ } Rex::get_cache()->run("LC_ALL=C hostname -f 2>/dev/null");
         ($domain) = grep { $_=$2 if /^([^\.]+)\.(.*)$/ } Rex::get_cache()->run("LC_ALL=C hostname -f 2>/dev/null");

         if(! $hostname || $hostname eq "") {
            Rex::Logger::debug("Error getting hostname and domainname. There is something wrong with your /etc/hosts file.");
            $hostname = Rex::get_cache()->run("LC_ALL=C hostname");
         }
      }

      return {
      
         manufacturer => $bios->get_system_information()->get_manufacturer() || "",
         hostname     => $hostname || "",
         domain       => $domain || "",
         operatingsystem => $os || "",
         operatingsystemrelease => Rex::get_cache()->call_sub("Rex::Hardware::Host", "get_operating_system_version") || "",
         kernelname => [ run "uname -s" ]->[0],

      };

   }
   else {
      return {
         operatingsystem => $^O,
      };
   }

}

sub get_operating_system {

   # use lsb_release if available
   my $is_lsb = Rex::get_cache()->can_run("lsb_release");

   if($is_lsb) {
      if(my $ret = run "lsb_release -s -i") {
         if($ret eq "SUSE LINUX") {
            $ret = "SuSE";
         }
         return $ret;
      }
   }

   if(is_file("/etc/debian_version")) {
      return "Debian";
   }

   if(is_file("/etc/SuSE-release")) {
      return "SuSE";
   }

   if(is_file("/etc/mageia-release")) {
      return "Mageia";
   }

   if(is_file("/etc/gentoo-release")) {
      return "Gentoo";
   }

   if(is_file("/etc/altlinux-release")) {
      return "ALT";
   }

   if(is_file("/etc/redhat-release")) {
      my $fh = file_read("/etc/redhat-release");
      my $content = $fh->read_all;
      $fh->close;
      chomp $content;

      if($content =~ m/CentOS/) {
         return "CentOS";
      }
      elsif($content =~ m/Scientific/) {
         return "Scientific";
      }
      else {
         return "Redhat";
      }
   }

   my $os_string = Rex::get_cache()->run("uname -s");
   return $os_string;   # return the plain os


}

sub get_operating_system_version {
   
   my $op = Rex::get_cache()->call_sub("Rex::Hardware::Host", "get_operating_system");

   my $is_lsb = Rex::get_cache()->can_run("lsb_release");

   # use lsb_release if available
   if($is_lsb) {
      if(my $ret = run "lsb_release -r -s") {
         my $os_check = run "lsb_release -d";
         unless($os_check =~ m/SUSE\sLinux\sEnterprise\sServer/) {
            return $ret;
         }
      }
   }

   if($op eq "Debian") {

      my $fh = file_read("/etc/debian_version");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      return $content;

   }
   elsif($op eq "Ubuntu") {
      my @l = run "lsb_release -r -s";
      return $l[0];
   }
   elsif(lc($op) eq "redhat" 
            or lc($op) eq "centos"
            or lc($op) eq "scientific") {

      my $fh = file_read("/etc/redhat-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      $content =~ m/(\d+(\.\d+)?)/;

      return $1;

   }
   elsif($op eq "Mageia") {
      my $fh = file_read("/etc/mageia-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      $content =~ m/(\d+)/;

      return $1;
   }

   elsif($op eq "Gentoo") {
      my $fh = file_read("/etc/gentoo-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      return [ split(/\s+/, $content) ]->[-1];
   }

   elsif($op eq "SuSE") {
      
      my ($version,$release);

      my $fh = file_read("/etc/SuSE-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      if($content =~ m/SUSE\sLinux\sEnterprise\sServer/m) {
         ($version,$release) = $content =~ m/VERSION\s=\s(\d+)\nPATCHLEVEL\s=\s(\d+)/m;
         $version = "$version.$release";
      }
      else {
         ($version) = $content =~ m/VERSION = (\d+\.\d+)/m;
      }

      return $version;

   }
   elsif($op eq "ALT" ) {
      my $fh = file_read("/etc/altlinux-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      $content =~ m/(\d+(\.\d+)*)/;

      return $1;

   }
   elsif($op =~ /BSD/) {
      my ($version) = grep { $_=$1 if /(\d+\.\d+)/ } run "uname -r";
      return $version;
   }

   return [ Rex::get_cache()->run("uname -r") ]->[0];

}

1;
