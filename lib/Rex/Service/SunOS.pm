#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::SunOS;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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
    start   => '/etc/init.d/%s start',
    restart => '/etc/init.d/%s restart',
    stop    => '/etc/init.d/%s stop',
    reload  => '/etc/init.d/%s reload',
    status  => '/etc/init.d/%s status',
    action  => '/etc/init.d/%s %s',
  };

  return $self;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    eval { i_run "rm /etc/rc*.d/S*$service"; };
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    my ($runlevel) = map { /run-level (\d)/ } i_run "who -r";
    ln "/etc/init.d/$service", "/etc/rc${runlevel}.d/S99$service";
  }

  return 1;
}

1;
