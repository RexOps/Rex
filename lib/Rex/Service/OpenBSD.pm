#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::OpenBSD;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Commands::File;
use Rex::Logger;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start        => '/usr/sbin/rcctl start %s',
    restart      => '/usr/sbin/rcctl restart %s',
    stop         => '/usr/sbin/rcctl stop %s',
    reload       => '/usr/sbin/rcctl reload %s',
    status       => '/usr/sbin/rcctl check %s',
    ensure_start => '/usr/sbin/rcctl enable %s',
    ensure_stop  => '/usr/sbin/rcctl disable %s',
    action       => '/usr/sbin/rcctl action %s',
  };

  return $self;
}

1;
