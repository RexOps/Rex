#
# (c) Giuseppe Di Terlizzi <giuseppe.diterlizzi@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Slackware;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start          => '/etc/rc.d/rc.%s start',
    restart        => '/etc/rc.d/rc.%s restart',
    stop           => '/etc/rc.d/rc.%s stop',
    reload         => '/etc/rc.d/rc.%s reload',
    status         => '/etc/rc.d/rc.%s status',
    ensure_stop    => 'chmod -x /etc/rc.d/rc.%s',
    ensure_start   => 'chmod +x /etc/rc.d/rc.%s',
    action         => '/etc/rc.d/rc.%s %s',
    service_exists => 'test -e /etc/rc.d/rc.%s',
  };

  return $self;
}

1;
