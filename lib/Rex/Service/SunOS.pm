#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::SunOS;

use strict;
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
    start   => '/etc/init.d/%s start >/dev/null',
    restart => '/etc/init.d/%s restart >/dev/null',
    stop    => '/etc/init.d/%s stop >/dev/null',
    reload  => '/etc/init.d/%s reload >/dev/null',
    status  => '/etc/init.d/%s status >/dev/null',
    action  => '/etc/init.d/%s %s >/dev/null',
  };

  return $self;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    i_run "rm /etc/rc*.d/S*$service";
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    my ($runlevel) = grep { $_ = $1 if m/run\-level (\d)/ } i_run "who -r";
    ln "/etc/init.d/$service", "/etc/rc${runlevel}.d/S99$service";
  }

  return 1;
}

1;
