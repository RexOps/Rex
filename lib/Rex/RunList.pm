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
  my ($class, %args) = @_;
  return bless \%args, $class;
}

# returns a singleton
sub instance {
  my $class = shift;
  return $INSTANCE if $INSTANCE;
  $INSTANCE = $class->new(@_);
}

sub add_task {
  my ($self, $task_name, $task_args, $task_opts) = @_;
  $task_args ||= [];
  $task_opts ||= {};
  my $task = $self->task_list->get_task($task_name)->clone;
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
  my $i = $self->current_index;
  $self->{tasks}->[$i];
}

sub tasks { @{ shift->{tasks} } }

sub task_list    { 
  my $self = shift;
  return $self->{task_list} if $self->{task_list};
  $self->{task_list} = Rex::TaskList->create;
}

sub run_tasks {
  my ($self) = @_;
  
  for my $task ($self->tasks) {
    $_->($task) for @{ $task->{before_task_start} };
    $self->task_list->run($task);
    $_->($task) for @{ $task->{after_task_finished} };
    $self->increment_current_index;
  }
}

# Parse @ARGV to get tasks, task args, and task opts.  Use these values to
# generate a list of tasks the user wants to run.
sub parse_opts {
  my ($self, @params) = @_;

  while (my $task_name = shift @params) {
    die "Expected a task name but found '$task_name' instead\n"
      unless $self->task_list->is_task($task_name);

    my @args;
    my %opts;

    while (my $param = shift @params) {
      if ($self->task_list->is_task($param)) {
        unshift @params, $param;
        last;
      }

      if ($param =~ /^--/) {
        my ($key, $val) = split /=/, $param, 2;
        $key =~ s/^--//;

        $opts{$key} = defined $val ? $val : 1;
      }
      else {
        push @args, $param;
      }
    }

    $self->add_task($task_name, \@args, \%opts);
  }

  return $self;
}

1;
