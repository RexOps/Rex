#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::SuSE;

use strict;
use warnings;

# VERSION

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Logger;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start        => '/etc/rc.d/%s start >/dev/null',
    restart      => '/etc/rc.d/%s restart >/dev/null',
    stop         => '/etc/rc.d/%s stop >/dev/null',
    reload       => '/etc/rc.d/%s reload >/dev/null',
    status       => '/etc/rc.d/%s status >/dev/null',
    ensure_stop  => 'chkconfig %s off',
    ensure_start => 'chkconfig %s on',
    action       => '/etc/rc.d/%s %s >/dev/null',
  };

  return $self;
}

1;
