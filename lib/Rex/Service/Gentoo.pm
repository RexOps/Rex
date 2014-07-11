#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Gentoo;

use strict;
use warnings;

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
    start        => '/etc/init.d/%s start >/dev/null',
    restart      => '/etc/init.d/%s restart >/dev/null',
    stop         => '/etc/init.d/%s stop >/dev/null',
    reload       => '/etc/init.d/%s reload >/dev/null',
    status       => '/etc/init.d/%s status >/dev/null',
    ensure_stop  => 'rc-update del %s',
    ensure_start => 'rc-update add %s',
    action       => '/etc/init.d/%s %s >/dev/null',
  };

  return $self;
}

1;
