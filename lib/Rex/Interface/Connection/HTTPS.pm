#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Connection::HTTPS;

use 5.010001;
use strict;
use warnings;
use Rex::Interface::Connection::HTTP;
use base qw(Rex::Interface::Connection::HTTP);

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub get_connection_type { return "HTTP"; }

sub _get_proto {
  return "https";
}

sub _get_port {
  my ( $self, $port ) = @_;
  return $port || 8443;
}

sub ua {
  my ($self) = @_;
  return $self->{ua} if $self->{ua};

  my $ssl_opts = {};

  if ( Rex::Config->get_ca ) {
    Rex::Logger::debug("SSL: Verifying Hostname");
    $ssl_opts->{verify_hostname} = 1;
    $ssl_opts->{SSL_ca_file}     = Rex::Config->get_ca;
  }
  else {
    Rex::Logger::debug("SSL: NOT Verifying Hostname");
    $ssl_opts->{verify_hostname} = 0;
  }

  if ( Rex::Config->get_ca_cert ) {
    $ssl_opts->{SSL_cert_file} = Rex::Config->get_ca_cert;
  }

  if ( Rex::Config->get_ca_key ) {
    $ssl_opts->{SSL_key_file} = Rex::Config->get_ca_key;
  }

  $self->{ua} = LWP::UserAgent->new( ssl_opts => $ssl_opts, );
}

1;
