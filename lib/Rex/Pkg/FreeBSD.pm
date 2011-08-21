#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::FreeBSD;

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

   run("pkg_info $pkg-*");

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

   Rex::Logger::debug("Version option not supported.");
   Rex::Logger::debug("Installing $pkg / $version");
   my $f = run("pkg_add -r $pkg");

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


   my ($pkg_found) = grep { $_->{"name"} eq "$pkg" } $self->get_installed();
   my $pkg_version = $pkg_found->{"version"};

   Rex::Logger::debug("Removing $pkg-$pkg_version");
   my $f = run("pkg_delete $pkg-$pkg_version");

   unless($? == 0) {
      Rex::Logger::info("Error removing $pkg-$pkg_version.");
      Rex::Logger::debug($f);
      die("Error removing $pkg-$pkg_version");
   }

   Rex::Logger::debug("$pkg-$pkg_version successfully removed.");

   return 1;
}


sub get_installed {
   my ($self) = @_;

   my @lines = run "pkg_info";

   my @pkg;

   for my $line (@lines) {
      my ($pkg_name_v, $descr) = split(/\s/, $line, 2);

      my ($pkg_name, $pkg_version) = ($pkg_name_v =~ m/^(.*)-(.*?)$/);

      push(@pkg, {
         name    => $pkg_name,
         version => $pkg_version,
      });
   }

   return @pkg;
}

sub update_pkg_db {
   my ($self) = @_;
   Rex::Logger::debug("Not supported under BSD");
}

sub add_repository {
   my ($self, %data) = @_;
   Rex::Logger::debug("Not supported under BSD");
}

sub rm_repository {
   my ($self, $name) = @_;
   Rex::Logger::debug("Not supported under BSD");
}


1;
