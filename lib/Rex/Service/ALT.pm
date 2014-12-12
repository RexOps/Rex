#
# ALT sevice control support
#
package Rex::Service::ALT;

use strict;
use warnings;

# VERSION

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start        => '/sbin/service %s start >/dev/null',
    restart      => '/sbin/service %s restart >/dev/null',
    stop         => '/sbin/service %s stop >/dev/null',
    reload       => '/sbin/service %s reload >/dev/null',
    status       => '/sbin/service %s status >/dev/null',
    ensure_stop  => '/sbin/chkconfig %s off',
    ensure_start => '/sbin/chkconfig %s on',
    action       => '/sbin/service %s %s >/dev/null',
  };

  return $self;
}

1;
