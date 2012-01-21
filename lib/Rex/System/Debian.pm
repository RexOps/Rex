#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::System::Debian;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Host;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub default_language {
   my ($self, $lang) = @_;

   if(is_file("/etc/default/locale")) {
      my @content = split /\n/, cat "/etc/default/locale";

      eval {
         my $fh = file_write "/etc/default/locale";
         for my $line (@content) {
            $line =~ s/^([^=]+)=.*$/$1="$lang"/;
            $fh->write($line . "\n");
         }

         $fh->close;
      };

      if($@) {
         die("Error writing /etc/default/locale");
      }

   }
   else {
      # create a new file
      my $fh = file_write "/etc/default/locale";
      $fh->write("LANG=\"$lang\"\n");
      $fh->close;
   }
}

sub languages {
   my ($self, @langs) = @_;

   eval {
      my $fh = file_write "/etc/locale.gen";

      for my $lang (@langs) {
         $fh->write($lang . "\n");
      }

      $fh->close;
   };

   if($@) {
      die("Error writing /etc/locale.gen");
   }

   run "/usr/sbin/locale-gen";
}

sub keyboard {
   my ($self, $layout) = @_;

   if(is_file("/etc/default/keyboard")) {
      my @content = split /\n/, cat "/etc/default/keyboard";


      eval {

         my $fh = file_write "/etc/default/keyboard";

         for my $line (@content) {
            if($line =~ m/^XKBLAYOUT=/) {
               $fh->write("XKBLAYOUT=\"$layout\"\n");
               next;
            }

            $fh->write("$line\n");
         }

         $fh->close;
      };

      if($@) {
         die("Error writing /etc/default/keyboard");
      }
   }
   else {
      # create a new file
      my $fh = file_write "/etc/default/keyboard";
      $fh->write("XKBLAYOUT=\"$layout\"\n");
      $fh->close;
   }

}

sub timezone {
   my ($self, $timezone) = @_;

   eval {
      my $fh = file_write "/etc/timezone";
      $fh->write("$timezone\n");
      $fh->close;
   };

   if($@) {
      die("Error writing /etc/timezone");
   }

}

sub network {
   my ($self, $dev, %option) = @_;

   my @content = split /\n/, cat "/etc/network/interfaces";

   eval {

      my $fh = file_append "/etc/network/interfaces";

      $fh->write("\n");

      $fh->write("auto $dev\n");
      if($option{proto} eq "dhcp") {
         $fh->write("iface $dev inet dhcp\n");
      }
      else {
         unless(exists $option{ip}) {
            die("You have to set at least ip and netmask");
         }
         unless(exists $option{netmask}) {
            die("You have to set at least ip and netmask");
         }


         $fh->write("iface $dev inet static\n");
         $fh->write("\taddress $option{ip}\n");
         $fh->write("\tnetmask $option{netmask}\n");
         if(exists $option{gateway}) {
            $fh->write("\tgateway $option{gateway}\n");
         }

         if(exists $option{broadcast}) {
            $fh->write("\tbroadcast $option{broadcast}\n");
         }

         if(exists $option{network}) {
            $fh->write("\tnetwork $option{network}\n");
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
      file "/etc/hostname",
         content => "$hostname";

      run "hostname $hostname";
   }
   else {
      return cat "/etc/hostname";
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
