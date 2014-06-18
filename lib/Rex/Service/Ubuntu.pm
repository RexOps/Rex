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
    start        => '/sbin/service %s start >/dev/null',
    restart      => '/sbin/service %s restart >/dev/null',
    stop         => '/sbin/service %s stop >/dev/null',
    reload       => '/sbin/service %s reload >/dev/null',
    status       => '/sbin/service %s status >/dev/null',
    ensure_stop  => 'update-rc.d -f %s remove',
    ensure_start => 'update-rc.d %s defaults',
    action       => '/sbin/service %s %s >/dev/null',
  };

  return $self;
}


sub status {
  my ( $self, $service, $options ) = @_;

  my $ret = $self->SUPER::status($service, $options);


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
