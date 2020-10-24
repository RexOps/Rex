#
# ALT sevice control support
#
package Rex::Service::ALT;

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
    start        => '/sbin/service %s start',
    restart      => '/sbin/service %s restart',
    stop         => '/sbin/service %s stop',
    reload       => '/sbin/service %s reload',
    status       => '/sbin/service %s status',
    ensure_stop  => '/sbin/chkconfig %s off',
    ensure_start => '/sbin/chkconfig %s on',
    action       => '/sbin/service %s %s',
  };

  return $self;
}

1;
