#
# Work with ALT Linux APT-RPM package management system
#

package Rex::Pkg::ALT;

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

   run("/usr/bin/rpm -ql $pkg");

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

   my $version = $option->{"version"} || "";

   Rex::Logger::debug("Installing $pkg / $version");
   my $f = run("/usr/bin/apt-get -y install $pkg" . ($version?"-$version":""));

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
   my $f = run("/usr/bin/apt-get -y remove $pkg");

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

   my @lines = run '/usr/bin/rpm -qa --nodigest --qf "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"';

   my @pkg;

   for my $line (@lines) {
      if($line =~ m/^([^\s]+)\s([^\s]+)\s([^\s]+)\s([^\s]+)\s(.*)$/) {
         push(@pkg, {
            name    => $1,
            epoch   => $2,
            version => $3,
            release => $4,
            arch    => $5,
         });
      }
   }

   return @pkg;
}

sub update_pkg_db {
   my ($self) = @_;

   run "/usr/bin/apt-get update";
   if($? != 0) {
      die("Error updating package repository");
   }
}

sub add_repository {
   my ($self, %data) = @_;
   my $name = $data{"name"};
   my $sign = $data{"sign_key"} || "";
   my @arch = split(/, */, $data{"arch"});

   my $fh = file_write "/etc/apt/sources.list.d/$name.list";
   $fh->write("# This file is managed by Rex\n");

   foreach(@arch) {
       $fh->write("rpm " .($sign?"[".$sign."] ":""). $data{"url"} . " " . $_ . " " . $data{"repository"} . "\n");
   };
   $fh->close;
}

sub rm_repository {
   my ($self, $name) = @_;
   unlink "/etc/apt/sources.list.d/$name.list";
}

1;
