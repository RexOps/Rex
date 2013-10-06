#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::Debian;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;

use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub is_installed {

   my ($self, $pkg) = @_;

   Rex::Logger::debug("Checking if $pkg is installed");

   my @pkg_info = $self->get_installed($pkg);

   unless(@pkg_info) {
      Rex::Logger::debug("$pkg is NOT installed.");
      return 0;
   }
   
   Rex::Logger::debug("$pkg is installed.");
   return 1;

}

sub install {
   my ($self, $pkg, $option) = @_;

   if($self->is_installed($pkg) && ! $option->{"version"}) {
      Rex::Logger::info("$pkg is already installed");
      return 1;
   }

   $self->update($pkg, $option);

   return 1;
}

sub bulk_install {
   my ($self, $packages_aref, $option) = @_;
   
   delete $option->{version}; # makes no sense to specify the same version for several packages
    
   $self->update("@{$packages_aref}", $option);
   
   return 1;
}

sub update {
   my ($self, $pkg, $option) = @_;

   my $version = $option->{'version'} || '';

   Rex::Logger::debug("Installing $pkg / $version");
   my $f = i_run("DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold --force-yes -y install $pkg" . ($version?"=$version":""));

   unless($? == 0) {
      Rex::Logger::info("Error installing $pkg.", "warn");
      Rex::Logger::debug($f);
      die("Error installing $pkg");
   }

   Rex::Logger::debug("$pkg successfully installed.");

   return 1;
}

sub update_system {
   my ($self) = @_;
   i_run("apt-get -y upgrade");
}

sub remove {
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Removing $pkg");
   my $f = i_run("apt-get -y remove $pkg");

   Rex::Logger::debug("Purging $pkg");
   i_run("dpkg --purge $pkg");

   unless($? == 0) {
      Rex::Logger::info("Error removing $pkg.", "warn");
      Rex::Logger::debug($f);
      die("Error removing $pkg");
   }

   Rex::Logger::debug("$pkg successfully removed.");

   return 1;
}


sub get_installed {
   my ($self, $pkg) = @_;
   my @pkgs;
   my $dpkg_cmd = 'dpkg-query -W --showformat "\${Status} \${Package}|\${Version}\n"';
   if ($pkg) {
       $dpkg_cmd .= " ". $pkg;
   }
   
   my @lines = i_run $dpkg_cmd;

   for my $line (@lines) {
      if($line =~ m/^install ok installed ([^\|]+)\|(.*)$/) {
         push(@pkgs, {
            name    => $1,
            version => $2,
         });
      }
   }

   return @pkgs;
}

sub update_pkg_db {
   my ($self) = @_;

   i_run "apt-get -y update";
   if($? != 0) {
      die("Error updating package database");
   }
}

sub add_repository {
   my ($self, %data) = @_;

   my $name = $data{"name"};

   my $fh = file_write "/etc/apt/sources.list.d/$name.list";
   $fh->write("# This file is managed by Rex\n");
   if(exists $data{"arch"}) {
      $fh->write("deb [arch=" . $data{"arch"} . "] " . $data{"url"} . " " . $data{"distro"} . " " . $data{"repository"} . "\n");
   }
   else {
      $fh->write("deb " . $data{"url"} . " " . $data{"distro"} . " " . $data{"repository"} . "\n");
   }
   if(exists $data{"source"} && $data{"source"}) {
      $fh->write("deb-src " . $data{"url"} . " " . $data{"distro"} . " " . $data{"repository"} . "\n");
   }
   $fh->close;

   if(exists $data{"key_url"}) {
      i_run "wget -O - " . $data{"key_url"} . " | apt-key add -";
   }

   if(exists $data{"key_id"} && $data{"key_server"}) {
      i_run "apt-key adv --keyserver " . $data{"key_server"} . " --recv-keys " . $data{"key_id"};
   }
}

sub rm_repository {
   my ($self, $name) = @_;
   unlink "/etc/apt/sources.list.d/$name.list";
}


1;
