#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::OpenBSD;

use strict;
use warnings;

# VERSION

use Rex::Commands::Run;
use Rex::Commands::File;

use Rex::Pkg::NetBSD;

use base qw(Rex::Pkg::NetBSD);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

1;
