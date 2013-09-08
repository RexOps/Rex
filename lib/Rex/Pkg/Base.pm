#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Pkg::Base;

use strict;
use warnings;
use Rex::Interface::Exec;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub is_installed {
   Rex::Logger::info("Checking for installed package not supported on this platform", "warn");
}

sub install {
   Rex::Logger::info("Installing package not supported on this platform", "warn");
}

sub bulk_install {
   Rex::Logger::info("Installing bulk packages not supported on this platform. Falling back to one by one method", "warn");

   my ($self, $packages_aref, $option) = @_;
   for my $pkg_to_install (@{$packages_aref}) {
      $self->install($pkg_to_install, $option);
   }
   
   return 1;
}

sub update {
   Rex::Logger::info("Updating package not supported on this platform", "warn");
}

sub update_system {
   Rex::Logger::info("Complete system update not supported on this platform", "warn");
}

sub remove {
   Rex::Logger::info("Removing package not supported on this platform", "warn");
}

sub get_installed {
   Rex::Logger::info("Listing installed packages not supported on this platform", "warn");
}

sub update_pkg_db {
   Rex::Logger::info("Updating package database not supported on this platform", "warn");
}

sub add_repository {
   Rex::Logger::info("Adding new repositories not supported on this platform", "warn");
}

sub rm_repository {
   Rex::Logger::info("Removing repositories not supported on this platform", "warn");
}

sub _exec {
   my ($self, $cmd) = @_;
   my $exec = Rex::Interface::Exec->create;
   $exec->exec($cmd);
}
1;
