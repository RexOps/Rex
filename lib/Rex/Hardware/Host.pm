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

sub get {

   return {
   
      manufacturer => [ run("dmidecode -t chassis") =~ m/Manufacturer: ([^\n]+)/ ]->[0],
      hostname     => run("hostname"),
      domain       => run("dnsdomainname"),
      operatingsystem => get_operating_system(),
      operatingsystemrelease => get_operating_system_version(),

   };

}

sub get_operating_system {

   if(is_file("/etc/debian_version")) {
      return "Debian";
   }

   if(is_file("/etc/SuSE-release")) {
      return "SuSE";
   }

   if(is_file("/etc/redhat-release")) {
      my $fh = file_read("/etc/redhat-release");
      my $content = $fh->read_all;
      $fh->close;
      chomp $content;

      if($content =~ m/CentOS/) {
         return "CentOS";
      }
      else {
         return "Redhat";
      }
   }

   return "Unknown";

}

sub get_operating_system_version {
   
   my $op = get_operating_system();

   if($op eq "Debian") {

      my $fh = file_read("/etc/debian_version");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      return $content;

   }
   elsif($op eq "Redhat" or $op eq "CentOS") {

      my $fh = file_read("/etc/redhat-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      $content =~ m/(\d+\.\d+)/;

      return $1;

   }
   elsif($op eq "SuSE") {
      
      my $fh = file_read("/etc/SuSE-release");
      my $content = $fh->read_all;
      $fh->close;

      chomp $content;

      $content =~ m/VERSION = (\d+\.\d+)/m;

      return $1;

   }

   return "Unknown";

}

1;
