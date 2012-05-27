#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::Debian;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::File;

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

   run("dpkg -L $pkg");

   unless($? == 0) {
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

sub update {
   my ($self, $pkg, $option) = @_;

   my $version = $option->{'version'} || '';

   Rex::Logger::debug("Installing $pkg / $version");
   my $f = run("DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold --force-yes -y install $pkg" . ($version?"=$version":""));

   unless($? == 0) {
      Rex::Logger::info("Error installing $pkg.", "warn");
      Rex::Logger::debug($f);
      die("Error installing $pkg");
   }

   Rex::Logger::debug("$pkg successfully installed.");

   return 1;
}

sub remove {
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Removing $pkg");
   my $f = run("apt-get -y remove $pkg");

   Rex::Logger::debug("Purging $pkg");
   run("dpkg --purge $pkg");

   unless($? == 0) {
      Rex::Logger::info("Error removing $pkg.", "warn");
      Rex::Logger::debug($f);
      die("Error removing $pkg");
   }

   Rex::Logger::debug("$pkg successfully removed.");

   return 1;
}


sub get_installed {
   my ($self) = @_;

   my @lines = run 'dpkg-query -W --showformat "\${Status} \${Package}|\${Version}\n"';

   my @pkg;

   for my $line (@lines) {
      if($line =~ m/^install ok installed ([^\|]+)\|(.*)$/) {
         push(@pkg, {
            name    => $1,
            version => $2,
         });
      }
   }

   return @pkg;
}

sub update_pkg_db {
   my ($self) = @_;

   run "apt-get -y update";
   if($? != 0) {
      die("Error updating package database");
   }
}

sub add_repository {
   my ($self, %data) = @_;

   my $name = $data{"name"};

   my $fh = file_write "/etc/apt/sources.list.d/$name.list";
   $fh->write("# This file is managed by Rex\n");
   $fh->write("deb " . $data{"url"} . " " . $data{"distro"} . " " . $data{"repository"} . "\n");
   if(exists $data{"source"} && $data{"source"}) {
      $fh->write("deb-src " . $data{"url"} . " " . $data{"distro"} . " " . $data{"repository"} . "\n");
   }
   $fh->close;
}

sub rm_repository {
   my ($self, $name) = @_;
   unlink "/etc/apt/sources.list.d/$name.list";
}


1;
