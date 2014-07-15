#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::OpenSSH;

use strict;
use warnings;

use Rex::Helper::SSH2;
require Rex::Commands;
use Rex::Interface::Exec::SSH;

use base qw(Rex::Interface::Exec::SSH);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub _exec {
  my ( $self, $exec ) = @_;

  my $ssh = Rex::is_ssh();
  my ( $out, $err ) = $ssh->capture2($exec);
  if($ssh->error) {
    $? = $? >> 8;
  }

  return ( $out, $err );
}

1;
