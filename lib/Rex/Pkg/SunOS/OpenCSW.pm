#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::SunOS::OpenCSW;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Pkg::SunOS;

use base qw(Rex::Pkg::SunOS);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub install {
   my ($self, $pkg, $option) = @_;

   if($self->is_installed($pkg) && ! $option->{"version"}) {
      Rex::Logger::info("$pkg is already installed");
      return 1;
   }

   my $version = $option->{'version'} || '';

   Rex::Logger::debug("Version option not supported.");
   Rex::Logger::debug("Installing $pkg");

   my $cmd = $self->_pkgutil() . " --yes -i $pkg";
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

   my $cmd = $self->_pkgutil() . " --yes -r $pkg";
   my $f = run($cmd . " $pkg");

   unless($? == 0) {
      Rex::Logger::info("Error removing $pkg.");
      Rex::Logger::debug($f);
      die("Error removing $pkg");
   }

   Rex::Logger::debug("$pkg successfully removed.");

   return 1;
}


sub update_pkg_db {
   my ($self) = @_;
   run $self->_pkgutil() . " -U";
}

sub _pkgutil {
   return "/opt/csw/bin/pkgutil";
}

1;
