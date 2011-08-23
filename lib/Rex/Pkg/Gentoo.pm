#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::Gentoo;

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

   run("equery list $pkg");

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

   my $version = $option->{'version'} || '';
   if($version) {
      $pkg = "=$pkg=$version";
   }

   Rex::Logger::debug("Installing $pkg / $version");
   my $f = run("emerge $pkg");

   unless($? == 0) {
      Rex::Logger::info("Error installing $pkg.");
      Rex::Logger::debug($f);
      die("Error installing $pkg");
   }

   Rex::Logger::debug("$pkg successfully installed.");

   return 1;
}

sub remove {
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Removing $pkg");
   my $f = run("emerge --depclean $pkg");

   unless($? == 0) {
      Rex::Logger::info("Error removing $pkg.");
      Rex::Logger::debug($f);
      die("Error removing $pkg");
   }

   Rex::Logger::debug("$pkg successfully removed.");

   return 1;
}


sub get_installed {
   my ($self) = @_;

   Rex::Logger::info("todo");
}

sub update_pkg_db {
   my ($self) = @_;

   run "emerge --sync";
   if($? != 0) {
      die("Error updating package database");
   }
}

sub add_repository {
   my ($self, %data) = @_;

   my $name = $data{"name"};
   Rex::Logger::info("todo");
}

sub rm_repository {
   my ($self, $name) = @_;
   Rex::Logger::info("todo");
}


1;
