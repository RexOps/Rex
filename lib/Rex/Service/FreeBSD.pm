#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Service::FreeBSD;

use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Logger;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start   => '/usr/local/etc/rc.d/%s onestart >/dev/null',
    restart => '/usr/local/etc/rc.d/%s onerestart >/dev/null',
    stop    => '/usr/local/etc/rc.d/%s onestop >/dev/null',
    reload  => '/usr/local/etc/rc.d/%s onereload >/dev/null',
    status  => '/usr/local/etc/rc.d/%s onestatus >/dev/null',
    action  => '/usr/local/etc/rc.d/%s %s >/dev/null',
  };

  return $self;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    delete_lines_matching "/etc/rc.conf",
      matching => qr/${service}_enable="YES"/;
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    append_if_no_such_line "/etc/rc.conf", "${service}_enable=\"YES\"\n";
  }

  return 1;
}

1;
