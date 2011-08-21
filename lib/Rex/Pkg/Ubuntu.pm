#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Pkg::Ubuntu;

use strict;
use warnings;

use Rex::Pkg::Debian;
use Rex::Commands::Run;
use Rex::Commands::File;

use base qw(Rex::Pkg::Debian);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}


