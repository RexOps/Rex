#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Service::Redhat::systemd;

use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Logger;
use Rex::Commands::Fs;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start          => 'systemctl start %s >/dev/null',
    restart        => 'systemctl restart %s >/dev/null',
    stop           => 'systemctl stop %s >/dev/null',
    reload         => 'systemctl reload %s >/dev/null',
    status         => 'systemctl status %s >/dev/null',
    ensure_stop    => 'systemctl disable %s',
    ensure_start   => 'systemctl enable %s',
    service_exists => 'systemctl show %s | grep LoadState=loaded',
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

  i_run "systemctl $action $service >/dev/null", nohup => 1;
  if ( $? == 0 ) { return 1; }
}

1;
