#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::OpenWrt;

use strict;
use warnings;

# VERSION

use Rex::Service::Debian;
use base qw(Rex::Service::Debian);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start        => '/etc/init.d/%s start',
    restart      => '/etc/init.d/%s restart',
    stop         => '/etc/init.d/%s stop',
    reload       => '/etc/init.d/%s reload',
    status       => '/sbin/start-stop-daemon -K -t -q -n %s',
    ensure_stop  => '/etc/init.d/%s disable',
    ensure_start => '/etc/init.d/%s enable',
    action       => '/etc/init.d/%s %s',
  };

  return $self;
}

1;
