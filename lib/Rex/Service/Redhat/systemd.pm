#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::Redhat::systemd;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::Run;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start          => 'systemctl --no-pager start %s',
    restart        => 'systemctl --no-pager restart %s',
    stop           => 'systemctl --no-pager stop %s',
    reload         => 'systemctl --no-pager reload %s',
    status         => 'systemctl --no-pager is-active %s',
    ensure_stop    => 'systemctl --no-pager disable %s',
    ensure_start   => 'systemctl --no-pager enable %s',
    service_exists => 'systemctl --no-pager show %s | grep LoadState=loaded',
  };

  return $self;
}

# all systemd services must end with .service
# so it will be appended if there is no "." in the name.
sub _prepare_service_name {
  my ( $self, $service ) = @_;

  unless ( $service =~ m/\./ ) {
    $service .= ".service";
  }

  $self->SUPER::_prepare_service_name($service);

  return $service;
}

sub action {
  my ( $self, $service, $action ) = @_;

  my $ret_val;
  eval {
    i_run "systemctl --no-pager $action $service >/dev/null", nohup => 1;
    $ret_val = 1;
    1;
  } or do {
    $ret_val = 0;
  };

  return $ret_val;
}

1;
