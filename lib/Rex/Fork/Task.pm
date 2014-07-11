#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Fork::Task;

BEGIN {

  use Rex::Shared::Var;
  share qw(@PROCESS_LIST);

}

use strict;
use warnings;
use POSIX ":sys_wait_h";

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{'running'} = 0;

  return $self;
}

sub start {
  my ($self) = @_;
  $self->{'running'} = 1;
  if ( $self->{pid} = fork ) { return $self->{pid}; }
  else {
    $self->{chld} = 1;
    my $func = $self->{task};
    if ($Rex::WITH_EXIT_STATUS) {
      eval {
        &$func($self);
        1;
      } or do {
        push( @PROCESS_LIST, 1 );
        $self->{'running'} = 0;
        die($@);
      };

      $self->{'running'} = 0;
      push( @PROCESS_LIST, 0 );
      exit();
    }
    else {
      &$func($self);
      $self->{'running'} = 0;
      exit();
    }
  }
}

sub wait {
  my ($self) = @_;
  my $rpid = waitpid( $self->{pid}, &WNOHANG );
  if ( $rpid == -1 ) { $self->{'running'} = 0; }

  return $rpid;
}

1;
