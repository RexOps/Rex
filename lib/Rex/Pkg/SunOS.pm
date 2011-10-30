#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::SunOS;

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

   run("pkginfo $pkg");

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

   my $cmd = "pkgadd ";

   if(! exists $option->{"source"}) {
      die("You have to specify the source.");
   }

   $cmd .= " -a " . $option->{"adminfile"} if($option->{"adminfile"});
   $cmd .= " -r " . $option->{"responsefile"} if($option->{"responsefile"});

   $cmd .= " -d " . $option->{"source"};
   $cmd .= " -n " . $pkg;

   my $f = run($cmd);

   unless($? == 0) {
      Rex::Logger::info("Error installing $pkg.");
      Rex::Logger::debug($f);
      die("Error installing $pkg");
   }

   Rex::Logger::debug("$pkg successfully installed.");

   return 1;
}

sub remove {
   my ($self, $pkg, $option) = @_;


   Rex::Logger::debug("Removing $pkg");

   my $cmd = "pkgrm -n ";
   $cmd .= " -a " . $option->{"adminfile"} if($option->{"adminfile"});

   my $f = run($cmd . " $pkg");

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

   my @lines = run "pkginfo -l";

   my (@pkg, %current);

   for my $line (@lines) {
      if($line =~ m/^$/) {
         push(@pkg, { %current });
         next;
      }

      if($line =~ m/PKGINST:\s+([^\s]+)/) {
         $current{"name"} = $1;
         next;
      }

      if($line =~ m/VERSION:\s+([^\s]+)/) {
         my ($version, $rev) = split(/,/, $1);
         $current{"version"} = $version;
         $rev =~ s/^REV=// if($rev);
         $current{"revision"} = $rev;
         next;
      }


      if($line =~ m/STATUS:\s+(.*?)$/) {
         $current{"status"} = ($1 eq "completely installed"?"installed":$1);
         next;
      }

   }

   return @pkg;
}

sub update_pkg_db {
   my ($self) = @_;
   Rex::Logger::debug("Not supported under Solaris");
}

sub add_repository {
   my ($self, %data) = @_;
   Rex::Logger::debug("Not supported under Solaris");
}

sub rm_repository {
   my ($self, $name) = @_;
   Rex::Logger::debug("Not supported under Solaris");
}


1;
