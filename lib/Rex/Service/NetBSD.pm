#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::NetBSD;

use strict;
use warnings;

# VERSION

use Rex::Commands::File;
use Rex::Logger;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start   => '/etc/rc.d/%s onestart',
    restart => '/etc/rc.d/%s onerestart',
    stop    => '/etc/rc.d/%s onestop',
    reload  => '/etc/rc.d/%s onereload',
    status  => '/etc/rc.d/%s onestatus',
    action  => '/etc/rc.d/%s %s',
  };

  return $self;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    file "/etc/rc.conf.d/${service}", ensure => "absent";
    delete_lines_matching "/etc/rc.conf",
      matching => qr/^\s*${service}="?((?i)YES)"?/;
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    file "/etc/rc.conf.d/${service}", ensure => "absent";
    append_or_amend_line "/etc/rc.conf",
      line   => "${service}=YES",
      regexp => qr/^\s*${service}="?((?i)YES|NO)"?/;
  }

  return 1;
}

1;
