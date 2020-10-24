#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::IOReader;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use IO::Select;

sub io_read {
  my ( $self, $out_fh, $err_fh, $pid, $option ) = @_;
  my ( $out, $err, $out_line, $err_line );

  my $selector = IO::Select->new();
  $selector->add($out_fh);
  $selector->add($err_fh);

  my $rex_int_conf = Rex::Commands::get("rex_internals") || {};
  my $buffer_size  = 1024;
  if ( exists $rex_int_conf->{read_buffer_size} ) {
    $buffer_size = $rex_int_conf->{read_buffer_size};
  }

  my ( $last_line_stdout, $last_line_stderr ) = ( "", "" );

  while ( my @ready = $selector->can_read ) {
    foreach my $fh (@ready) {
      my $buf = "";

      my $len = sysread $fh, $buf, $buffer_size;
      $selector->remove($fh) unless $len;

      $buf =~ s/\r?\n/\n/g; # normalize EOL characters

      # append buffer to the proper overall output
      $out .= $buf if $fh == $out_fh;
      $err .= $buf if $fh == $err_fh;

      if ( $buf =~ /\n/ ) { # buffer has one or more newlines
        my @line_chunks = split /\n/, $buf;

        my $partial_last_chunk = '';
        if ( $buf !~ /\n$/ ) { # last chunk is partial
          $partial_last_chunk = pop @line_chunks;
        }

        foreach my $chunk (@line_chunks) {
          if ( $fh == $out_fh ) {
            $out_line .= $chunk;
            $self->execute_line_based_operation( $out_line, $option )
              && do { kill( 'KILL', $pid ); goto END_OPEN };
            $out_line = '';
          }
          elsif ( $fh == $err_fh ) {
            $err_line .= $chunk;
            $self->execute_line_based_operation( $err_line, $option )
              && do { kill( 'KILL', $pid ); goto END_OPEN };
            $err_line = '';
          }
        }

        if ($partial_last_chunk) { # append partial chunk to line if present
          $out_line .= $partial_last_chunk if $fh == $out_fh;
          $err_line .= $partial_last_chunk if $fh == $err_fh;
        }

      }
      else {                       # buffer doesn't have any newlines
        $out_line .= $buf if $fh == $out_fh;
        $err_line .= $buf if $fh == $err_fh;
      }
    }
  }

  unless ($out) {
    $out = $last_line_stdout;
    $self->execute_line_based_operation( $out, $option )
      && do { kill( 'KILL', $pid ); goto END_OPEN };
  }

  unless ($err) {
    $err = $last_line_stderr;
    $self->execute_line_based_operation( $err, $option )
      && do { kill( 'KILL', $pid ); goto END_OPEN };
  }

END_OPEN:

  return ( $out, $err );
}

1;
