#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Executor::Default;

use strict;
use warnings;

use Rex::Hook;
use Rex::Logger;
use Data::Dumper;

use Rex::Interface::Executor::Base;
use base qw(Rex::Interface::Executor::Base);

require Rex::Args;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub exec {
  my ( $self, $opts ) = @_;

  $opts ||= { Rex::Args->get };

  my $task = $self->{task};

  Rex::Logger::debug( "Executing " . $task->name );

  my $ret;
  eval {
    my $code = $task->code;

    Rex::Hook::run_hook( task => "before_execute", $task->name, @_ );

    $ret = &$code($opts);

    Rex::Hook::run_hook( task => "after_execute", $task->name, @_ );
  };

  my %opts = Rex::Args->getopts;
  if ($@) {
    my $error = $@;
    if ( exists $opts{o} ) {
      Rex::Output->get->add( $task->name, error => 1, msg => $@ );
    }
    else {
      Rex::Logger::info( "Error executing task:", "error" );
      Rex::Logger::info( "$error",                "error" );
      die($@);
    }
  }
  else {
    if ( exists $opts{o} ) {
      Rex::Output->get->add( $task->name );
    }
  }

  return $ret;
}

1;
