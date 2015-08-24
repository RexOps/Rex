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

  my $rcout = i_run "/usr/sbin/service $service rcvar";

  my ( $rcvar, $rcvalue );
  unless ( ( $rcvar, $rcvalue ) = $rcout =~ m/^(\S+)=(\S+)$/m ) {
    Rex::Logger::info(
      "Service $service can't be started: not installed or no such rc scipt.",
      "error" );
    return 0;
  }
  $rcvar = $rcvar =~ s/^\$//r;

  my $status = i_run "/usr/sbin/service $service onestatus";

  if ( $what =~ /^stop/ ) {
    if ( $rcvalue =~ m/^"?YES"?$/i ) {
      file "/etc/rc.conf.d/${service}", ensure => "absent";
      if ( is_file("/etc/rc.conf.local") ) {
        delete_lines_matching "/etc/rc.conf.local",
          matching => qr/^\s*${rcvar}=((?i)YES|"YES"|'YES')/;
      }
      delete_lines_matching "/etc/rc.conf",
        matching => qr/^\s*${rcvar}=((?i)YES|"YES"|'YES')/;
    }
    if ( $status =~ m/is running/ ) {
      $self->stop( $service, $options );
    }
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    unless ( $rcvalue =~ m/^"?YES"?$/i ) {
      file "/etc/rc.conf.d/${service}", ensure => "absent";
      if ( is_file("/etc/rc.conf.local") ) {
        delete_lines_matching "/etc/rc.conf.local",
          matching => qr/^\s*${rcvar}=/;
      }
      append_or_amend_line "/etc/rc.conf",
        line   => "${rcvar}=\"YES\"",
        regexp => qr/^\s*${rcvar}=/;
    }
    if ( $status =~ m/is not running/ ) {
      $self->start( $service, $options );
    }
  }

  return 1;
}

1;
