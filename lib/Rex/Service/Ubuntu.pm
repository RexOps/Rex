#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Ubuntu;

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
    start        => '/usr/sbin/service %s start >/dev/null',
    restart      => '/usr/sbin/service %s restart >/dev/null',
    stop         => '/usr/sbin/service %s stop >/dev/null',
    reload       => '/usr/sbin/service %s reload >/dev/null',
    status       => '/usr/sbin/service %s status >/dev/null',
    ensure_stop  => '/usr/sbin/update-rc.d -f %s remove',
    ensure_start => '/usr/sbin/update-rc.d %s defaults',
    action       => '/usr/sbin/service %s %s >/dev/null',
  };

  return $self;
}

sub status {
  my ( $self, $service, $options ) = @_;

  my $ret = $self->SUPER::status( $service, $options );

  # bad... really bad ...
  if ( $ret == 0 ) {
    return 0;
  }

  my $output = $self->get_output;

  if ( $output =~ m/NOT running|stop\//ms ) {
    return 0;
  }

  return 1;
}

1;
