#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::SuSE;

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
   my ($self, $pkg) = @_;

   Rex::Logger::debug("Installing $pkg");
   my $f = run("zypper -n install $pkg");

   unless($? == 0) {
      Rex::Logger::info("Error installing $pkg.");
      Rex::Logger::debug($f);
      return 0;
   }

   Rex::Logger::debug("$pkg successfully installed.");

   return 1;
}


1;
