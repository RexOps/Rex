#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Task - Functions to work with tasks

=head1 DESCRIPTION

This module contains the functions you need to work with tasks.

=head1 SYNOPSIS


=head1 EXPORTED FUNCTIONS

 do_task "task_name";
 run_task "task_name", on => "server_name";
 needs "task_name";

=cut

package Rex::Commands::Task;

use strict;
use warnings;

# VERSION

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT =
  qw(task desc batch do_task run_task run_batch needs environment no_ssh);

our ( $current_desc, $global_no_ssh, $dont_register_tasks,
  $REGISTER_SUB_HASH_PARAMETER );

=head2 task($name [, @servers], $funcref)

This function will create a new task.

=over 4

=item Create a local task (a server independent task)

 task "mytask", sub {
   say "Do something";
 };

If you call this task with (R)?ex it will run on your local machine. You can explicit run this task on other machines if you specify the I<-H> command line parameter.

=item Create a server bound task.

 task "mytask", "server1", sub {
   say "Do something";
 };

You can also specify more than one server.

 task "mytask", "server1", "server2", "server3", sub {
   say "Do something";
 };

Or you can use some expressions to define more than one server.

 task "mytask", "server[1..3]", sub {
   say "Do something";
 };

If you want, you can overwrite the servers with the I<-H> command line parameter.

=item Create a group bound task.

You can define server groups with the I<group> function.

 group "allserver" => "server[1..3]", "workstation[1..10]";

 task "mytask", group => "allserver", sub {
   say "Do something";
 };

=back

=cut

sub task {
  my ( $class, $file, @tmp ) = caller;
  my @_ARGS = @_;

  if ( !@_ ) {
    if ( my $t = Rex::get_current_connection() ) {
      return $t->{task}->[-1];
    }
    return;
  }

  # for things like
  # no_ssh task ...
  if (wantarray) {
    return sub {
      my %option = @_;

      $option{class} = $class;
      $option{file}  = $file;
      $option{tmp}   = \@tmp;

      task( @_ARGS, \%option );
    };
  }

  if ( ref( $_ARGS[-1] ) eq "HASH" ) {
    if ( $_ARGS[-1]->{class} ) {
      $class = $_ARGS[-1]->{class};
    }

    if ( $_ARGS[-1]->{file} ) {
      $file = $_ARGS[-1]->{file};
    }

    if ( $_ARGS[-1]->{tmp} ) {
      @tmp = @{ $_ARGS[-1]->{tmp} };
    }
  }

  my $task_name      = shift;
  my $task_name_save = $task_name;

  if ( $task_name !~ m/^[a-zA-Z_][a-zA-Z0-9_]*$/
    && !Rex::Config->get_disable_taskname_warning() )
  {
    Rex::Logger::info(
      "Please use only the following characters for task names:", "warn" );
    Rex::Logger::info( "  A-Z, a-z, 0-9 and _",                      "warn" );
    Rex::Logger::info( "Also the task should start with A-Z or a-z", "warn" );
    Rex::Logger::info(
      "You can disable this warning by setting feature flag: disable_taskname_warning",
      "warn"
    );
  }

  my $options = {};

  if ( ref( $_[-1] ) eq "HASH" ) {
    $options = pop;
  }

  if ($global_no_ssh) {
    $options->{"no_ssh"} = 1;
  }

  if ( $class ne "main" && $class ne "Rex::CLI" ) {
    $task_name = $class . ":" . $task_name;
  }

  $task_name =~ s/^Rex:://;
  $task_name =~ s/::/:/g;

  if ($current_desc) {
    push( @_, $current_desc );
    $current_desc = "";
  }
  else {
    push( @_, "" );
  }

  no strict 'refs';
  no warnings;
  push( @{"${class}::tasks"}, { name => $task_name_save, code => $_[-2] } );
  use strict;
  use warnings;

  $options->{'dont_register'} ||= $dont_register_tasks;
  my $task_o = Rex::TaskList->create()->create_task( $task_name, @_, $options );

  if (!$class->can($task_name_save)
    && $task_name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    no strict 'refs';
    Rex::Logger::debug("Registering task: $task_name");
    my $code = $_[-2];
    *{"${class}::$task_name_save"} = sub {
      Rex::Logger::info("Running task $task_name on current connection");
      my $param;

      if ( scalar @_ == 1 && ref $_[0] eq "HASH" ) {
        $param = $_[0];
      }
      elsif ( $REGISTER_SUB_HASH_PARAMETER && scalar @_ % 2 == 0 ) {
        $param = {@_};
      }
      else {
        $param = \@_;
      }

      $task_o->run( "<func>", params => $param );
    };
  }

  $options->{'dont_register'} ||= $dont_register_tasks;
  return $task_o;
}

=head2 desc($description)

Set the description of a task.

 desc "This is a task description of the following task";
 task "mytask", sub {
   say "Do something";
 }

=cut

sub desc {
  $current_desc = shift;
}

=head2 batch($name, @tasks)

With the batch function you can call tasks in a batch.

 batch "name", "task1", "task2", "task3";

And call it with the I<-b> console parameter. I<rex -b name>

=cut

sub batch {
  if ($current_desc) {
    push( @_, $current_desc );
    $current_desc = "";
  }
  else {
    push( @_, "" );
  }

  Rex::Batch->create_batch(@_);
}

=head2 do_task($task)

Call $task from another task. It will establish a new connection to the server defined in $task and then execute $task there.

 task "task1", "server1", sub {
   say "Running on server1";
   do_task "task2";
 };

 task "task2", "server2", sub {
   say "Running on server2";
 };

You may also use an arrayRef for $task if you want to call multiple tasks.

 do_task [ qw/task1 task2 task3/ ];

=cut

sub do_task {
  my $task   = shift;
  my $params = shift;

  if ( ref($task) eq "ARRAY" ) {
    for my $t ( @{$task} ) {
      Rex::TaskList->create()->get_task($t) || die "Task $t not found.";
      Rex::TaskList->run( $t, ( $params ? ( params => $params ) : () ) );
    }
  }
  else {
    Rex::TaskList->create()->get_task($task) || die "Task $task not found.";
    return Rex::TaskList->run( $task,
      ( $params ? ( params => $params ) : () ) );
  }
}

=head2 run_task($task_name, %option)

Run a task on a given host.

 my $return = run_task "taskname", on => "192.168.3.56";

Do something on server5 if memory is less than 100 MB free on server3.

 task "prepare", "server5", sub {
   my $free_mem = run_task "get_free_mem", on => "server3";
   if($free_mem < 100) {
     say "Less than 100 MB free mem on server3";
     # create a new server instance on server5 to unload server3
   }
 };

 task "get_free_mem", sub {
    return memory->{free};
 };

If called without a hostname the task is run localy.

 # this task will run on server5
 task "prepare", "server5", sub {
   # this will call task check_something. but this task will run on localhost.
   my $check = run_task "check_something";
 }

 task "check_something", "server4", sub {
   return "foo";
 };

If you want to add custom parameters for the task you can do it this way.

 task "prepare", "server5", sub {
  run_task "check_something", on => "foo", params => { param1 => "value1", param2 => "value2" };
 };

=cut

sub run_task {
  my ( $task_name, %option ) = @_;

  if ( exists $option{on} ) {
    my $task = Rex::TaskList->create()->get_task($task_name);
    if ( exists $option{params} ) {
      $task->run( $option{on}, params => $option{params} );
    }
    else {
      $task->run( $option{on} );
    }
  }
  else {
    my $task = Rex::TaskList->create()->get_task($task_name);
    if ( exists $option{params} ) {
      $task->run( "<local>", params => $option{params} );
    }
    else {
      $task->run("<local>");
    }
  }

}

=head2 run_batch($batch_name, %option)

Run a batch on a given host.

 my @return = run_batch "batchname", on => "192.168.3.56";

It calls internally run_task, and passes it any option given.

=cut

sub run_batch {
  my ( $batch_name, %option ) = @_;

  my @tasks = Rex::Batch->get_batch($batch_name);
  my @results;
  for my $task (@tasks) {
    my $return = run_task $task, %option;
    push @results, $return;
  }

  return @results;
}

=head2 needs($package [, @tasks])

With I<needs> you can define dependencies between tasks. The "needed" tasks will be called with the same server configuration as the calling task.

I<needs> will not execute before, around and after hooks.

=over 4

=item Depend on all tasks in a given package.

Depend on all tasks in the package MyPkg. All tasks will be called with the server I<server1>.

 task "mytask", "server1", sub {
   needs MyPkg;
 };

=item Depend on a single task in a given package.

Depend on the I<uname> task in the package MyPkg. The I<uname> task will be called with the server I<server1>.

 task "mytask", "server1", sub {
   needs MyPkg "uname";
 };

=item To call tasks defined in the Rexfile from within a module

 task "mytask", "server1", sub {
   needs main "uname";
 };


=back

=cut

sub needs {
  my ( $self, @args ) = @_;

  # if no namespace is given, use the current one
  if ( ref($self) eq "ARRAY" ) {
    @args = @{$self};
    ($self) = caller;
  }

  if ( $self eq "main" ) {
    $self = "Rex::CLI";
  }

  no strict 'refs';
  my @maybe_tasks_to_run = @{"${self}::tasks"};
  use strict;

  if ( !@args && !@maybe_tasks_to_run ) {
    @args = ($self);
    ($self) = caller;
  }

  if ( ref( $args[0] ) eq "ARRAY" ) {
    @args = @{ $args[0] };
  }

  Rex::Logger::debug("need to call tasks from $self");

  no strict 'refs';
  my @tasks_to_run = @{"${self}::tasks"};
  use strict;

  my $run_list     = Rex::RunList->instance;
  my $current_task = $run_list->current_task;
  my %task_opts    = $current_task->get_opts;
  my @task_args    = $current_task->get_args;

  for my $task (@tasks_to_run) {
    my $task_name = $task->{"name"};
    if ( @args && grep ( /^$task_name$/, @args ) ) {
      Rex::Logger::debug( "Calling " . $task->{"name"} );
      $task->{"code"}->( \%task_opts, \@task_args );
    }
    elsif ( !@args ) {
      Rex::Logger::debug( "Calling " . $task->{"name"} );
      $task->{"code"}->( \%task_opts, \@task_args );
    }
  }

}

# register needs in main namespace
{
  my ($caller_pkg) = caller(1);

  if ( !$caller_pkg ) {
    ($caller_pkg) = caller(0);
  }

  if ( $caller_pkg && ( $caller_pkg eq "Rex::CLI" || $caller_pkg eq "main" ) ) {
    no strict 'refs';
    *{"main::needs"} = \&needs;
    use strict;
  }
};

=head2 no_ssh([$task])

Disable ssh for all tasks or a specified task.

If you want to disable ssh connection for your complete tasks (for example if you only want to use libVirt) put this in the main section of your Rexfile.

 no_ssh;

If you want to disable ssh connection for a given task, put I<no_ssh> in front of the task definition.

 no_ssh task "mytask", "myserver", sub {
   say "Do something without a ssh connection";
 };

=cut

sub no_ssh {
  if (@_) {
    $_[0]->( no_ssh => 1 );
  }
  else {
    $global_no_ssh = 1;
  }
}

1;
