#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::SunOS::svcadm;

use strict;
use warnings;

# VERSION

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
    start   => 'svcadm enable %s >/dev/null',
    restart => 'svcadm restart %s >/dev/null',
    stop    => 'svcadm disable %s >/dev/null',
    reload  => 'svcadm refresh %s >/dev/null',
  };

  return $self;
}

sub status {
  my ( $self, $service, $options ) = @_;

  my ($state) = map { /state\s+([a-z]+)/ } eval { i_run "svcs -l $service"; };

  if ( $state eq "online" ) {
    return 1;
  }

  return 0;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
  }

  return 1;
}

sub action {
  my ( $self, $service, $action ) = @_;

  my $ret_val;
  eval {
    i_run "svcadm $action $service >/dev/null", nohup => 1;
    $ret_val = 1;
  } or do {
    $ret_val = 0;
  };

  return $ret_val;
}

1;
