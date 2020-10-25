#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Profiler;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Time::HiRes qw(gettimeofday tv_interval);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{__data} = {};

  return $self;
}

sub start {
  my ( $self, $info ) = @_;

  push(
    @{ $self->{__data}->{$info} },
    {
      start => [gettimeofday]
    }
  );
}

sub end {
  my ( $self, $info ) = @_;

  return unless ( $self->{__data}->{$info}->[-1] );

  my $data = $self->{__data}->{$info}->[-1];
  $data->{end}      = [gettimeofday];
  $data->{duration} = tv_interval( $data->{start}, $data->{end} );

  $self->{__data}->{$info}->[-1] = $data;
}

sub report {
  my ($self) = @_;

  for my $info ( keys %{ $self->{__data} } ) {
    print "# $info (count: " . scalar( @{ $self->{__data}->{$info} } ) . ")\n";
    print "  Timings:\n";

    my ( $max, $min, $avg, $all );
    for my $entry ( @{ $self->{__data}->{$info} } ) {
      if ( !$max || $max < $entry->{duration} ) {
        $max = $entry->{duration};
      }

      if ( !$min || $min > $entry->{duration} ) {
        $min = $entry->{duration};
      }

      $all += $entry->{duration};
    }

    $avg = $all / scalar( @{ $self->{__data}->{$info} } );

    print "    min: $min / max: $max / avg: $avg / all: $all\n";
    print "  Overview:\n";

    for my $entry ( @{ $self->{__data}->{$info} } ) {
      print "    " . $entry->{duration} . "\n";
    }

    print
      "--------------------------------------------------------------------------------\n";
  }
}

1;
