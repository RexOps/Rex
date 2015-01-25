#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::OpenSSH;

use strict;
use warnings;

# VERSION

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
  my ( $self, $exec, $option ) = @_;
  my ( $out, $err, $pid, $out_fh, $err_fh );
  my $ssh = Rex::is_ssh();

  ( undef, $out_fh, $err_fh, $pid ) = $ssh->open3( {}, $exec );
  while ( my $line = <$out_fh> ) {
    $out .= $line;
    $self->execute_line_based_operation( $line, $option )
      && do { kill( 'KILL', $pid ); goto END_OPEN };

  }
  while ( my $line = <$err_fh> ) {
    $err .= $line;
    $self->execute_line_based_operation( $line, $option )
      && do { kill( 'KILL', $pid ); goto END_OPEN };
  }

END_OPEN:
  waitpid( $pid, 0 ) or die($!);
  if ( $ssh->error || $? ) {
    $? = $? >> 8;
  }

  return ( $out, $err );
}
1;
