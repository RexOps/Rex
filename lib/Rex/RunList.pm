#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::RunList;

use strict;
use warnings;

use Rex::Logger;
use Rex::TaskList;

# VERSION

my $INSTANCE;

sub new {
  my ( $class, %args ) = @_;
  return bless \%args, $class;
}

# returns a singleton
sub instance {
  my $class = shift;
  return $INSTANCE if $INSTANCE;
  $INSTANCE = $class->new(@_);
}

sub add_task {
  my ( $self, $task_name, $task_args, $task_opts ) = @_;
  $task_args ||= [];
  $task_opts ||= {};
  my $task = $self->task_list->get_task($task_name);
  $task->set_args(@$task_args);
  $task->set_opts(%$task_opts);
  push @{ $self->{tasks} }, $task;
}

sub current_index {
  my ($self) = @_;
  return $self->{current_index} || 0;
}

sub increment_current_index {
  my ($self) = @_;
  return $self->{current_index} += 1;
}

sub current_task {
  my $self = shift;
  my $i    = $self->current_index;
  $self->{tasks}->[$i];
}

sub tasks { @{ shift->{tasks} || [] } }

sub task_list {
  my $self = shift;
  return $self->{task_list} if $self->{task_list};
  $self->{task_list} = Rex::TaskList->create;
}

sub run_tasks {
  my ($self) = @_;

  for my $task ( $self->tasks ) {
    Rex::TaskList->run($task);
    $self->increment_current_index;
  }
}

# Parse @ARGV to get tasks, task args, and task opts.  Use these values to
# generate a list of tasks the user wants to run.
sub parse_opts {
  my ( $self, @params ) = @_;

  return $self->pre_1_4_parse_opts(@params)
    unless Rex::Config->get_task_chaining_cmdline_args;

  while ( my $task_name = shift @params ) {
    $self->exit_rex($task_name) unless $self->task_list->is_task($task_name);

    my @args;
    my %opts;

    while ( my $param = shift @params ) {
      if ( $self->task_list->is_task($param) ) {
        unshift @params, $param;
        last;
      }

      if ( $param =~ /^--/ ) {
        my ( $key, $val ) = split /=/, $param, 2;
        $key =~ s/^--//;

        $opts{$key} = defined $val ? $val : 1;
      }
      else {
        push @args, $param;
      }
    }

    $self->add_task( $task_name, \@args, \%opts );
  }

  return $self;
}

# this function is to parse the task parameters in a pre 1.4 fashion.
# this is used if the feature flag 'no_task_chaining_cmdline_args' or
# '< 1.4' is enabled.
sub pre_1_4_parse_opts {
  my ( $self, @params ) = @_;

  #### parse task options
  my %task_opts;

  for my $p (@params) {
    my ( $key, $val ) = split( /=/, $p, 2 );

    $key =~ s/^--//;

    if ( defined $val ) { $task_opts{$key} = $val; next; }
    $task_opts{$key} = 1;
  }

  for my $task_name (@params) {
    next if $task_name =~ m/^\-\-/ || $task_name =~ m/=/;
    $self->exit_rex($task_name) unless $self->task_list->is_task($task_name);
    $self->add_task( $task_name, [], \%task_opts );
  }
}

sub exit_rex {
  my ( $self, $task_name ) = @_;
  my $msg = "Task names are case sensitive ";
  $msg .= "and the module delimiter is a single colon.";
  Rex::Logger::info( "No task named '$task_name' found. $msg", 'error' );
  Rex::CLI::exit_rex(1);
}

1;
