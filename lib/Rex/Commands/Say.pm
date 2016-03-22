#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Say - Custom say function

=head1 DESCRIPTION

This module exports a custom say function. This function is deprecated

and is not loaded if feature flags >= 1.5 are enabled.

=head1 SYNOPSIS

 say "Hello World.";
 say_format '%D - %h: %s';

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Say;

use strict;
use warnings;

# VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(say sayformat say_format format_str);

=head2 sayformat($format)

You can define the format of the say() function.

%D - The current date yyyy-mm-dd HH:mm:ss

%h - The target host

%p - The pid of the running process

%s - The Logstring

You can also define the following values:

default - the default behaviour.

asis - will print every single parameter in its own line. This is useful if you want to print the output of a command.

=cut

sub sayformat {
  my ($format) = @_;
  Rex::Config->set_say_format($format);
}

sub say_format { sayformat(@_); }

=head2 say($line1, $line2)

Print a message and add a newline at the end.
This function is deprecated and the internal perl I<say> function should be used.

=cut

sub say {
  my (@data) = @_;

  return unless defined $_[0];

  my $format = Rex::Config->get_say_format;
  if ( !defined $format || $format eq "default" ) {
    print @_, "\n";
    return;
  }

  if ( $format eq "asis" ) {
    print join( "\n", @_ );
    return;
  }

  for my $line (@data) {
    print _format_string( $format, $line ) . "\n";
  }

}

=head2 format_str($str)

Return the formated $str with the format that is defined with I<say_format>.

=cut

sub format_str {
  my ($str) = @_;

  my $format = Rex::Config->get_say_format;
  if ( !defined $format || $format eq "default" || $format eq "asis" ) {
    return $str;
  }

  return _format_string( $format, $str );
}

# %D - Date
# %h - Host
# %s - Logstring
sub _format_string {
  my ( $format, $line ) = @_;

  my $date = _get_timestamp();
  my $host =
      Rex::get_current_connection()
    ? Rex::get_current_connection()->{conn}->server
    : "<local>";
  my $pid = $$;

  $format =~ s/\%D/$date/gms;
  $format =~ s/\%h/$host/gms;
  $format =~ s/\%s/$line/gms;
  $format =~ s/\%p/$pid/gms;

  return $format;
}

sub _get_timestamp {
  my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
    localtime(time);
  $mon++;
  $year += 1900;

  return
      "$year-"
    . sprintf( "%02i", $mon ) . "-"
    . sprintf( "%02i", $mday ) . " "
    . sprintf( "%02i", $hour ) . ":"
    . sprintf( "%02i", $min ) . ":"
    . sprintf( "%02i", $sec );
}

1;

