#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::SSH2;

use strict;
use warnings;

# VERSION

require Exporter;
use Data::Dumper;
require Rex::Commands;
use Time::HiRes qw(sleep);

use base qw(Exporter);

use vars qw(@EXPORT);
@EXPORT = qw(net_ssh2_exec net_ssh2_exec_output net_ssh2_shell_exec);

our $READ_STDERR    = 1;
our $EXEC_AND_SLEEP = 0;

sub net_ssh2_exec {
  my ( $ssh, $cmd, $base, $option ) = @_;

  my $chan = $ssh->channel;

  # REQUIRE_TTY can be turned off by feature no_tty
  if ( !Rex::Config->get_no_tty ) {
    $chan->pty("xterm"); # set to xterm, due to problems with vt100.
                         # if vt100 sometimes the restart of services doesn't work and need a sleep .000001 after the command...
                         # strange bug...
    $chan->pty_size( 4000, 80 );
  }
  $chan->blocking(1);

  $chan->exec($cmd);

  my $in;
  my $in_err = "";

  my $rex_int_conf = Rex::Commands::get("rex_internals") || {};
  my $buffer_size  = 1024;
  if ( exists $rex_int_conf->{read_buffer_size} ) {
    $buffer_size = $rex_int_conf->{read_buffer_size};
  }

  my @lines;
  my $last_line;
  my $current_line = "";
  while ( my $len = $chan->read( my $buf, $buffer_size ) ) {
    $in           .= $buf;
    $current_line .= $buf;

    if ( $buf =~ m/\n/ms ) {
      @lines = split( /\n/, $current_line );
      unshift @lines, $last_line if ($last_line);
      $last_line = pop @lines;

      for my $line (@lines) {
        $line =~ s/[\r\n]//gms;
        $line .= "\n";
        $base->execute_line_based_operation( $line, $option ) && goto END_READ;
      }

      $current_line = "";
    }

  }

  my @lines_err;
  my $last_line_err = "";
  while ( my $len = $chan->read( my $buf_err, $buffer_size, 1 ) ) {
    $in_err .= $buf_err;
    @lines_err = split( /\n/, $buf_err );
    unshift @lines_err, $last_line_err if ($last_line_err);
    $last_line_err = pop @lines_err;

    for my $line (@lines_err) {
      $line =~ s/[\r\n]//gms;
      $line .= "\n";
      $base->execute_line_based_operation( $line, $option ) && goto END_READ;
    }
  }

  #select undef, undef, undef, 0.002; # wait a little before closing the channel
  #sleep 1;
END_READ:
  $chan->send_eof;

  my $wait_c   = 0;
  my $wait_max = $rex_int_conf->{ssh2_channel_closewait_max} || 500;
  while ( !$chan->eof ) {
    Rex::Logger::debug("Waiting for eof on ssh channel.");
    sleep 0.002; # wait a little for retry
    $wait_c++;
    if ( $wait_c >= $wait_max ) {

      # channel will be force closed.
      Rex::Logger::debug(
        "Rex::Helper::SSH2::net_ssh2_exec: force closing channel for command: $cmd"
      );
      last;
    }
  }

  $chan->wait_closed;
  $? = $chan->exit_status;

  # if used with $chan->pty() we have to remove \r
  if ( !Rex::Config->get_no_tty ) {
    $in     =~ s/\r//g if $in;
    $in_err =~ s/\r//g if $in_err;
  }

  if (wantarray) {
    return ( $in, $in_err );
  }

  return $in;
}

sub net_ssh2_exec_output {
  my ( $ssh, $cmd, $callback ) = @_;

  my $chan = $ssh->channel;
  $chan->blocking(1);

  $chan->exec($cmd);

  while (1) {
    my $buf;
    my $buf_err;
    $chan->read( $buf,     15 );
    $chan->read( $buf_err, 15 );

    if ($callback) {
      &$callback( $buf, $buf_err );
    }
    else {
      print $buf;
      print $buf_err;
    }

    last unless $buf;
  }

  $chan->close;
  $? = $chan->exit_status;

}

1;
