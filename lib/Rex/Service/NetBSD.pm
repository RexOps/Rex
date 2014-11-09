#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Service::NetBSD;

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
    start   => '/etc/rc.d/%s onestart >/dev/null',
    restart => '/etc/rc.d/%s onerestart >/dev/null',
    stop    => '/etc/rc.d/%s onestop >/dev/null',
    reload  => '/etc/rc.d/%s onereload >/dev/null',
    status  => '/etc/rc.d/%s onestatus >/dev/null',
    action  => '/etc/rc.d/%s %s >/dev/null',
  };

  return $self;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    delete_lines_matching "/etc/rc.conf", matching => qr/${service}=YES/;
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    append_if_no_such_line "/etc/rc.conf", "${service}=YES\n";
  }

  return 1;
}

1;
