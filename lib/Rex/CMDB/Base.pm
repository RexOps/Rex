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

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub _parse_path {
  my ( $self, $path ) = @_;

  return parse_path($path);
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

1;
