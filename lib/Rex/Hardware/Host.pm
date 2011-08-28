#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Hardware::Host;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;

sub get {

   unless(can_run("dmidecode")) {
      Rex::Logger::debug("Please install dmidecode on the target system.");
   }

   my $domain;
   if(get_operating_system() eq "NetBSD" || get_operating_system() eq "OpenBSD") {
      ($domain) = grep { $_=$2 if /^([^\.]+)\.(.*)$/ } run("LC_ALL=C hostname");
   }
   else {
      ($domain) = grep { $_=$2 if /^([^\.]+)\.(.*)$/ } run("LC_ALL=C hostname -f");
   }

   return {
   
      manufacturer => [ run("LC_ALL=C dmidecode -t chassis") =~ m/Manufacturer: ([^\n]+)/ ]->[0],
      hostname     => run("LC_ALL=C hostname -s") || "",
      domain       => $domain || "",
      operatingsystem => get_operating_system(),
      operatingsystemrelease => get_operating_system_version(),

   };

}

sub get_operating_system {

   # use lsb_release if available
   if(can_run "lsb_release") {
      if(my $ret = run "lsb_release -s -i") {
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

   my $os_string = run "uname -s";
   return $os_string;   # return the plain os


}

sub get_operating_system_version {
   
   my $op = get_operating_system();

   # use lsb_release if available
   if(can_run "lsb_release") {
      if(my $ret = run "lsb_release -r -s") {
         return $ret;
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

      $content =~ m/(\d+\.\d+)/;

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
      
      my $fh = file_read("/etc/SuSE-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      $content =~ m/VERSION = (\d+\.\d+)/m;

      return $1;

   }
   elsif($op =~ /BSD/) {
      my ($version) = grep { $_=$1 if /(\d+\.\d+)/ } run "uname -r";
      return $version;
   }

   return "Unknown";

}

1;
