#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB::Base;

use strict;
use warnings;

require Rex::Commands;
require Rex::Commands::Gather;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub _parse_path {
  my ( $self, $path ) = @_;
  my %hw;
  $hw{server}      = Rex::Commands::connection()->server;
  $hw{environment} = Rex::Commands::environment();

  $path =~ s/\{(server|environment)\}/$hw{$1}/gms;

  if($path =~ m/\{([^\}]+)\}/) {
    # if there are still some variables to replace, we need some information of
    # the system.
    %hw = Rex::Commands::Gather::get_system_information();
    $path =~ s/\{([^\}]+)\}/$hw{$1}/gms;
  }


  return $path;
}



1;
