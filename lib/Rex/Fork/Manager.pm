#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Fork::Manager;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Fork::Task;
use Time::HiRes qw(sleep);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{'forks'}   = [];
  $self->{'running'} = 0;

  return $self;
}

sub add {
  my ( $self, $coderef ) = @_;

  my $f = Rex::Fork::Task->new( coderef => $coderef );

  push( @{ $self->{'forks'} }, $f );

  $f->start;
  ++$self->{'running'};

  if ( $self->{'running'} >= $self->{'max'} ) {
    $self->wait_for_one;
  }
}

sub start {
  my ($self) = @_;

  my @threads = @{ $self->{'forks'} };
  for ( my $i = 0 ; $i < scalar(@threads) ; ++$i ) {
    $threads[$i]->start;
    ++$self->{'running'};
    if ( $self->{'running'} >= $self->{'max'} ) {
      $self->wait_for_one;
    }
  }

  $self->wait_for_all;
}

sub wait_for_one {
  my ($self) = @_;
  $self->wait_for;
}

sub wait_for_all {
  my ($self) = @_;
  $self->wait_for(1);
}

sub wait_for {
  my ( $self, $all ) = @_;
  do {
    for ( my $i = 0 ; $i < scalar( @{ $self->{'forks'} } ) ; $i++ ) {
      my $thr = $self->{'forks'}->[$i];
      unless ( $thr->{'running'} ) {
        next;
      }

      my $kid;
      $kid = $thr->wait;

      if ( $kid == -1 ) {
        $thr = undef;
        $thr->{running} = 0;
        --$self->{'running'};

        return 1 unless $all;
      }
      sleep Rex::Config->get_waitpid_blocking_sleep_time;
    }
  } until $self->{'running'} == 0;
}

1;
