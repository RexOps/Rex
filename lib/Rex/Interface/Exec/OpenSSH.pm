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
use IO::Select;

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

  my $tty = !Rex::Config->get_no_tty;

  ( undef, $out_fh, $err_fh, $pid ) = $ssh->open3( { tty => $tty }, $exec );

  my $selector = IO::Select->new();
  $selector->add($out_fh);
  $selector->add($err_fh);

  my $line;

  while ( my @ready = $selector->can_read ) {
    foreach my $fh (@ready) {
      my $line = <$fh>;
      goto END_OPEN unless defined $line;
      $line =~ s/(\r?\n)$/\n/;

      $out .= $line if $fh == $out_fh;
      $err .= $line if $fh == $err_fh;

      $self->execute_line_based_operation( $line, $option )
        && do { kill( 'KILL', $pid ); goto END_OPEN };
    }
  }

END_OPEN:
  waitpid( $pid, 0 ) or die($!);
  return ( $out, $err );
}

1;
