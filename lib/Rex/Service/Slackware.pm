package Rex::Service::Slackware;

use strict;
use warnings;

# VERSION

use Fcntl qw(:mode);
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Logger;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start   => '/etc/rc.d/rc.%s start',
    restart => '/etc/rc.d/rc.%s restart',
    stop    => '/etc/rc.d/rc.%s stop',
    reload  => '/etc/rc.d/rc.%s reload',
    status  => '/etc/rc.d/rc.%s status',
    action  => '/etc/rc.d/rc.%s %s',
  };

  return $self;
}

sub _get_file_mode {
  my ( $self, $file ) = @_;

  my $mode;
  if ( is_file($file) ) {
    my %stat = stat $file;
    $mode = oct $stat{mode};
  }
  return $mode;
}

sub ensure {
  my ( $self, $service, $options ) = @_;

  my $what = $options->{ensure};

  my $script = sprintf '/etc/rc.d/rc.%s', $service;
  my $mode   = $self->_get_file_mode($script);
  if ( !defined $mode ) {
    Rex::Logger::info( "Startup script $script not found", 'error' );
    return 0;
  }

  if ( $what =~ /^stop/ ) {
    if ( ( $mode & S_IXUSR ) != 0 ) {
      $self->stop( $service, $options );
      file $script, mode => 'a-x';
    }
  }
  elsif ( $what =~ /^(?:start|run)/ ) {
    if ( ( $mode & S_IXUSR ) == 0 ) {
      file $script, mode => 'a+x';
      $self->start( $service, $options );
    }
  }

  return 1;
}

1;
