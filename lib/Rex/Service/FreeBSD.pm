#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::FreeBSD;

use strict;
use warnings;

# VERSION

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
    start   => '/usr/sbin/service %s onestart',
    restart => '/usr/sbin/service %s onerestart',
    stop    => '/usr/sbin/service %s onestop',
    reload  => '/usr/sbin/service %s onereload',
    status  => '/usr/sbin/service %s onestatus',
    action  => '/usr/sbin/service %s %s',
  };

  return $self;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    delete_lines_matching "/etc/rc.conf",
      matching => qr/${service}_enable="?[Yy][Ee][Ss]"?/;
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    append_if_no_such_line "/etc/rc.conf",
      line => "${service}_enable=\"YES\"",
      regexp => qr/^\s*${service}_enable="?[Yy][Ee][Ss]"?/;
  }

  return 1;
}

1;
