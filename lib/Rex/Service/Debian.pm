#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Debian;

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
    start          => '/etc/init.d/%s start',
    restart        => '/etc/init.d/%s restart',
    stop           => '/etc/init.d/%s stop',
    reload         => '/etc/init.d/%s reload',
    status         => '/etc/init.d/%s status',
    ensure_stop    => 'update-rc.d -f %s remove',
    ensure_start   => 'update-rc.d %s defaults',
    action         => '/etc/init.d/%s %s',
    service_exists => '/usr/sbin/service --status-all 2>&1 | grep %s',
  };

  return $self;
}

1;
