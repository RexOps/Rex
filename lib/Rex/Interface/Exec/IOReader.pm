#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::IOReader;

use strict;
use warnings;

# VERSION

use IO::Select;

sub io_read {
  my ( $self, $out_fh, $err_fh, $option ) = @_;
  my ( $out, $err, $pid );

  my $selector = IO::Select->new();
  $selector->add($out_fh);
  $selector->add($err_fh);

  my $rex_int_conf = Rex::Commands::get("rex_internals") || {};
  my $buffer_size = 1024;
  if ( exists $rex_int_conf->{read_buffer_size} ) {
    $buffer_size = $rex_int_conf->{read_buffer_size};
  }

  my ( $last_line_stdout, $last_line_stderr ) = ( "", "" );

  while ( my @ready = $selector->can_read ) {
    foreach my $fh (@ready) {
      my $buf = "";

      my $len = 0;
      my $concat_buf =
        ( $fh == $out_fh ? $last_line_stdout : $last_line_stderr );

      while ( $concat_buf !~ m/\n/ms ) {
        my $read_len = sysread $fh, $buf, $buffer_size;
        $len += $read_len;
        $concat_buf .= $buf;
        if ( !$read_len ) {
          last;
        }
      }

      $selector->remove($fh) unless $len;

      my @lines = split( /(\r?\n)/, $concat_buf );

      $last_line_stdout = pop @lines
        if ( $fh == $out_fh && $concat_buf !~ m/\n$/ms );
      $last_line_stderr = pop @lines
        if ( $fh == $err_fh && $concat_buf !~ m/\n$/ms );

      for my $line (@lines) {

        $out .= $line if $fh == $out_fh;
        $err .= $line if $fh == $err_fh;

        chomp $line;

        if ($line) {
          $self->execute_line_based_operation( $line, $option )
            && do { kill( 'KILL', $pid ); goto END_OPEN };
        }
      }
    }
  }

  unless ($out) {
    $out = $last_line_stdout;
    $self->execute_line_based_operation( $out, $option )
      && do { kill( 'KILL', $pid ); goto END_OPEN };
  }

  unless ($out) {
    $err = $last_line_stderr;
    $self->execute_line_based_operation( $err, $option )
      && do { kill( 'KILL', $pid ); goto END_OPEN };
  }

END_OPEN:
  return ( $out, $err );
}

1;
