#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::SuSE;

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
    start        => '/etc/rc.d/%s start',
    restart      => '/etc/rc.d/%s restart',
    stop         => '/etc/rc.d/%s stop',
    reload       => '/etc/rc.d/%s reload',
    status       => '/etc/rc.d/%s status',
    ensure_stop  => 'chkconfig %s off',
    ensure_start => 'chkconfig %s on',
    action       => '/etc/rc.d/%s %s',
  };

  return $self;
}

1;
