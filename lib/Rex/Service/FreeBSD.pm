#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service::FreeBSD;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::Run;
use Rex::Commands::Fs;
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

  my $rccom = "/usr/sbin/service $service rcvar";
  my $rcout;
  eval {
    $rcout = i_run $rccom;
    1;
  } or do {
    Rex::Logger::info( "Running `$rccom` failed", "error" );
    return 0;
  };

  my ( $rcvar, $rcvalue ) = $rcout =~ m/^\$?(\w+)="?(\w+)"?$/m;
  unless ($rcvar) {
    Rex::Logger::info( "Error getting service name.", "error" );
    return 0;
  }

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    my $stop_regexp = qr/^\s*${rcvar}=((?i)["']?YES["']?)/;
    if ( $rcvalue =~ m/^YES$/i ) {
      file "/etc/rc.conf.d/${service}",           ensure => "absent";
      file "/usr/local/etc/rc.conf.d/${service}", ensure => "absent";
      if ( is_file("/etc/rc.conf.local") ) {
        delete_lines_matching "/etc/rc.conf.local", matching => $stop_regexp;
      }
      delete_lines_matching "/etc/rc.conf", matching => $stop_regexp;
    }
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    my $start_regexp = qr/^\s*${rcvar}=/;
    unless ( $rcvalue =~ m/^YES$/i ) {
      file "/etc/rc.conf.d/${service}",           ensure => "absent";
      file "/usr/local/etc/rc.conf.d/${service}", ensure => "absent";
      if ( is_file("/etc/rc.conf.local") ) {
        delete_lines_matching "/etc/rc.conf.local", matching => $start_regexp;
      }
      append_or_amend_line "/etc/rc.conf",
        line   => "${rcvar}=\"YES\"",
        regexp => $start_regexp;
    }
  }

  return 1;
}

1;
