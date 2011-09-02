#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::SunOS::Blastwave;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Pkg::SunOS::OpenCSW;

use base qw(Rex::Pkg::SunOS::OpenCSW);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub _pkgutil { return "/opt/bw/bin/pkgutil"; }

1;
