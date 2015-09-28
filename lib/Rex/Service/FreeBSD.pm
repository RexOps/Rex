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

  my $get_rc_out = "/usr/sbin/service $service rcvar";
  my $rc_out     = i_run $get_rc_out;
  if ( $? != 0 ) {
    Rex::Logger::info( "Running `$get_rc_out` failed", "error" );
    return 0;
  }

  my ( $rcvar, $rcvalue ) = $rc_out =~ m/^\$?(\w+)="?(\w+)"?$/m;
  unless ($rcvar) {
    Rex::Logger::info( "Error getting service \$rcvar name.", "error" );
    return 0;
  }

  my $get_rcconf_out =
    "/bin/sh -c '. /etc/rc.subr; load_rc_config 'XXX'; echo \$rc_conf_files'";
  my $rcconf_out = i_run "$get_rcconf_out";
  if ( $? != 0 ) {
    Rex::Logger::info( "Running `$get_rcconf_out` failed", "error" );
    return 0;
  }
  my @rcconf = split /\s+/, $rcconf_out;
  unless (@rcconf) {
    Rex::Logger::info( "Error getting rc.conf files", "error" );
    return 0;
  }

  my $get_rcconfd_out =
    "/bin/sh -c '. /etc/rc.subr; load_rc_config 'XXX'; for dir in /etc \$local_startup; do dir=\${dir\%/rc.d}; echo \${dir}/rc.conf.d; done'";
  my $rcconfd_out = i_run "$get_rcconfd_out";
  if ( $? != 0 ) {
    Rex::Logger::info( "Running `$get_rcconfd_out` failed", "warn" );
  }
  my @rcconfd = split /\s+/, $rcconfd_out;
  unless (@rcconfd) {
    Rex::Logger::info( "Error getting rc.conf.d dirs", "warn" );
  }

  if ( $what =~ /^stop/ ) {
    $self->stop( $service, $options );
    my $stop_regexp = qr/^\s*${rcvar}=((?i)["']?YES["']?)/;
    if ( $rcvalue =~ m/^YES$/i ) {
      for my $rcconfd (@rcconfd) {
        file "${rcconfd}/${service}", ensure => "absent";
      }
      for my $rcconf (@rcconf) {
        if ( is_file($rcconf) ) {
          delete_lines_matching $rcconf, matching => $stop_regexp;
        }
      }
    }
  }
  elsif ( $what =~ /^start/ || $what =~ m/^run/ ) {
    $self->start( $service, $options );
    my $start_regexp = qr/^\s*${rcvar}=/;
    unless ( $rcvalue =~ m/^YES$/i ) {
      for my $rcconfd (@rcconfd) {
        file "${rcconfd}/${service}", ensure => "absent";
      }
      my $etc_rcconf = shift @rcconf;
      for my $rcconf (@rcconf) {
        if ( is_file($rcconf) ) {
          delete_lines_matching $rcconf, matching => $start_regexp;
        }
      }
      append_or_amend_line $etc_rcconf,
        line   => "${rcvar}=\"YES\"",
        regexp => $start_regexp;
    }
  }

  return 1;
}

1;
