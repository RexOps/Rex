#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB::Base;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::Path;
use Rex::Hardware;
use Rex::Hardware::Host;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub _parse_path {
  my ( $self, $path, $mapping ) = @_;

  return parse_path( $path, $mapping );
}

sub __get_hostname_for {
  my ( $self, $server ) = @_;

  my $hostname = $server // Rex::get_current_connection()->{conn}->server->to_s;

  if ( $hostname eq '<local>' ) {
    my %hw_info = Rex::Hardware->get('Host');
    $hostname = $hw_info{Host}{hostname};
  }

  return $hostname;
}

sub __warm_up_cache_for {
  my ( $self, $server ) = @_;

  $server = $self->__get_hostname_for($server);
  my $cache_key = $self->__cache_key("cmdb/$self/$server");

  if ( !$self->__cache->valid($cache_key) ) {
    my $cmdb = $self->get( undef, $server ) || undef;
    $self->__cache->set( $cache_key, $cmdb );
  }

  return $self->__cache;
}

sub __cache_key {
  my ( $self, $key ) = @_;

  if ( defined $key ) {
    $self->{__cache_key} = $key;
  }

  return $self->{__cache_key};
}

sub __cache {
  my ($self) = @_;

  if ( !defined $self->{__cache} ) {
    $self->{__cache} = Rex::get_cache();
  }

  return $self->{__cache};
}

1;
