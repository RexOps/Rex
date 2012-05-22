#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::Mageia;

use strict;
use warnings;

use Rex::Commands::Run;

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

   run("rpm -ql $pkg");

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

   my $f = run("urpmi --auto --quiet $pkg");

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
   my $f = run("urpme --auto $pkg");

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

   my @lines = run 'rpm -qa --nosignature --nodigest --qf "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"';

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

   run "urpmi.update -a";
   if($? != 0) {
      die("Error updating package repository");
   }
}
sub add_repository {
   my ($self, %data) = @_;
   my $name = $data{"name"};

   run "urpmi.addmedia $name " . $data{"url"};
   if($? != 0) {
      die("Error adding repository $name");
   }
}

sub rm_repository {
   my ($self, $name) = @_;
   run "urpmi.removemedia $name";
   if($? != 0) {
      die("Error removing repository $name");
   }
}

1;
