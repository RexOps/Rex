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
  my $i    = $self->current_index;
  $self->{tasks}->[$i];
}

sub tasks { @{ shift->{tasks} } }

sub task_list {
  my $self = shift;
  return $self->{task_list} if $self->{task_list};
  $self->{task_list} = Rex::TaskList->create;
}

sub run_tasks {
  my ($self) = @_;

  for my $task ( $self->tasks ) {
    $_->($task) for @{ $task->{before_task_start} };
    $self->task_list->run($task);
    $_->($task) for @{ $task->{after_task_finished} };
    $self->increment_current_index;
  }
}

# Parse @ARGV to get tasks, task args, and task opts.  Use these values to
# generate a list of tasks the user wants to run.
sub parse_opts {
  my ( $self, @params ) = @_;

  return $self->deprecated(@params)
    unless Rex::Config->get_task_chaining_cmdline_args;

  while ( my $task_name = shift @params ) {
    die "Expected a task name but found '$task_name' instead\n"
      unless $self->task_list->is_task($task_name);

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

sub deprecated {
  my ( $self, @params ) = @_;

  my $msg = <<EOF;
The default way command line arguments work will change somewhat in a future
release.  Major changes include:
 - Fixes for argument handling for multiple tasks (aka chained tasks).  
 - Tasks accept arguments as well as options.  
Use the feature 'task_chaining_cmdline_args' to remove this warning and enable
the new features.  For more info see:
http://www.rexify.org/docs/other/a_word_on_backward_compatibility.html
EOF
  Rex::Logger::info( $msg, 'warn' );

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
    next unless $self->task_list->is_task($task_name);

    $self->add_task( $task_name, [], \%task_opts );
  }
}

1;
