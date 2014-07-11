#
# Gentoo systemd support
#

package Rex::Service::Gentoo::systemd;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Logger;
use Rex::Commands::Fs;

use Rex::Service::Redhat::systemd;
use base qw(Rex::Service::Redhat::systemd);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

1;
