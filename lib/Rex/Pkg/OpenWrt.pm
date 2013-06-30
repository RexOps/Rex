#  OpenWrt.pm
#
#  Copyright 2013 Ferenc Erki <erkiferenc@gmail.com>
#
#  OpenWrt package management module for (R)?ex
#  based on Rex::Pkg::Debian

package Rex::Pkg::OpenWrt;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::File;
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

sub update {
   my ($self, $pkg, $option) = @_;

   my $version = $option->{'version'} || '';

   Rex::Logger::debug("Installing $pkg / $version");
   my $f = run("opkg install $pkg");

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
   my @pkgs;
   my @lines = run("opkg list-upgradable");

   for my $line (@lines) {
      if($line =~ m/^(.*) - .* - .*$/) { push(@pkgs, $1); }
   }

   my $packages_to_upgrade = join(" ", @pkgs);

   run("opkg upgrade " . $packages_to_upgrade);
}

sub remove {
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Removing $pkg");
   my $f = run("opkg remove $pkg");

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
   my $opkg_cmd = 'opkg list-installed';
   if ($pkg) {
       $opkg_cmd .= ' | grep "^' . $pkg . ' "';
   }

   my @lines = run $opkg_cmd;

   for my $line (@lines) {
      if($line =~ m/^(.*) - (.*)$/) {
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

   run "opkg update";
   if($? != 0) {
      die("Error updating package database");
   }
}

sub add_repository {
   my ($self, %data) = @_;
   append_if_no_such_line "/etc/opkg.conf",
      "src/gz " . $data{"name"} . " " . $data{"url"},
      $data{"name"},
      $data{"url"};
}

sub rm_repository {
   my ($self, $name) = @_;
   delete_lines_matching "/etc/opkg.conf" => "src/gz " . $name . " ";
}

1;
