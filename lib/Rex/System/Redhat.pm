#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::System::Redhat;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Host;
use Rex::Commands::Gather;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub default_language {
   my ($self, $lang) = @_;

   if(is_file("/etc/sysconfig/i18n")) {
      my @content = split /\n/, cat "/etc/sysconfig/i18n";

      eval {
         my $fh = file_write "/etc/sysconfig/i18n";
         for my $line (@content) {
            if($line =~ m/^LC_/ || $line =~ m/^LANG/) {
               $line =~ s/^([^=]+)=.*$/$1="$lang"/;
            }
            $fh->write($line . "\n");
         }

         $fh->close;
      };

      if($@) {
         die("Error writing /etc/sysconfig/i18n");
      }

   }
   else {
      # create a new file
      my $fh = file_write "/etc/sysconfig/i18n";
      $fh->write("LANG=\"$lang\"\n");
      $fh->close;
   }
}

sub languages {
   my ($self, @langs) = @_;

   for my $lang (@langs) {
      my ($lang_part, $enc_part) = split(/\./, $lang);
      run "/usr/bin/localedef -f $enc_part -i $lang_part $lang";
   }
}

sub keyboard {
   my ($self, $layout) = @_;

   if(is_file("/etc/sysconfig/keyboard")) {
      my @content = split /\n/, cat "/etc/sysconfig/keyboard";


      eval {

         my $fh = file_write "/etc/sysconfig/keyboard";

         for my $line (@content) {
            if($line =~ m/^KEYTABLE=/) {
               $fh->write("KEYTABLE=\"$layout\"\n");
               next;
            }

            $fh->write("$line\n");
         }

         $fh->close;
      };

      if($@) {
         die("Error writing /etc/sysconfig/keyboard");
      }
   }
   else {
      # create a new file
      my $fh = file_write "/etc/sysconfig/keyboard";
      $fh->write("KEYTABLE=\"$layout\"\n");
      $fh->write("KEYBOARDTYPE=\"pc\"\n");
      $fh->close;
   }

}

sub timezone {
   my ($self, $timezone) = @_;

   eval {
      cp "/usr/share/zoneinfo/$timezone", "/etc/localtime";
   };

   if($@) {
      die("Error writing /etc/localtime");
   }

}

sub network {
   my ($self, $dev, %option) = @_;

   eval {
      my $fh = file_write "/etc/sysconfig/network-scripts/ifcfg-$dev";
      my $mac = network_interfaces()->{$dev}->{mac};

      if($option{proto} eq "dhcp") {
         $fh->write("DEVICE=$dev\n");
         $fh->write("BOOTPROTO=dhcp\n");
         $fh->write("HWADDR=$mac\n");
      }
      else {
         unless(exists $option{ip}) {
            die("You have to set at least ip and netmask");
         }
         unless(exists $option{netmask}) {
            die("You have to set at least ip and netmask");
         }


         $fh->write("DEVICE=$dev\n");
         $fh->write("BOOTPROTO=static\n");
         $fh->write("IPADDR=$option{ip}\n");
         $fh->write("NETMASK=$option{netmask}\n");
         $fh->write("ONBOOT=yes\n");
         if(exists $option{gateway}) {
            $fh->write("GATEWAY=$option{gateway}\n");
         }

         if(exists $option{broadcast}) {
            $fh->write("BROADCAST=$option{broadcast}\n");
         }

         if(exists $option{network}) {
            $fh->write("NETWORK=$option{network}\n");
         }
      }

      $fh->close;

   };
}

sub write_boot_record {
   my ($self, $hd) = @_;
   Rex::Logger::info("Writing new MBR");
   run "grub-install /dev/$hd";
}

sub hostname {
   my ($self, $hostname) = @_;

   if($hostname) {
      my @content = split /\n/, cat "/etc/sysconfig/network";

      my $fh = file_write "/etc/sysconfig/network";
      for my $line (@content) {
         chomp $line;
         if($line =~ m/^HOSTNAME=/) {
            $fh->write("HOSTNAME=$hostname\n");
            next;
         }
         $fh->write("$line\n");
      }
      $fh->close;

      run "hostname $hostname";
   }
   else {
      my ($_key, $hostname) = split(/=/, [ grep { m/^HOSTNAME/ } split(/\n/, cat("/etc/sysconfig/network")) ]->[-1]);
      return $hostname;
   }
}

sub domainname {
   my ($self, $domainname) = @_;
   
   create_host $self->hostname().".$domainname", {
      ip      => "127.0.2.1",
      aliases => [$self->hostname()],
   };
}



1;
