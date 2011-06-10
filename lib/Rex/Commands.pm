#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands

=head1 DESCRIPTION

This module is the core commands module.

=head1 SYNOPSIS

 desc "Task description";
 
 task "taskname", sub { ... };
 task "taskname", "server1", ..., "server20", sub { ... };
 
 group "group" => "server1", "server2", ...;
 
 user "user";
 
 password "password";
 

=head1 COMMANDLIST

=over 4

=item * Database Commands L<Rex::Commands::DB>

=item * SCP Up- and Download L<Rex::Commands::Upload>, L<Rex::Commands::Download>

=item * File Manipulation L<Rex::Commands::File>

=item * Filesystem Manipulation L<Rex::Commands::Fs>

=item * Information Gathering L<Rex::Commands::Gather>

=item * Manipulation of /etc/hosts L<Rex::Commands::Host>

=item * Kernel Commands L<Rex::Commands::Kernel>

=item * Package Commands L<Rex::Commands::Pkg>

=item * Rsync Files L<Rex::Commands::Rsync>

=item * Run Remote Commands L<Rex::Commands::Run>

=item * Manage System Services (sysvinit) L<Rex::Commands::Service>

=item * Sysctl Commands L<Rex::Commands::Sysctl>

=item * Manage user and group accounts L<Rex::Commands::User>

=back

=head1 EXPORTED FUNCTIONS

=over 4

=cut



package Rex::Commands;

use strict;
use warnings;

use Data::Dumper;

require Exporter;
use Rex::Task;
use Rex::Logger;

use vars qw(@EXPORT $current_desc $global_no_ssh);
use base qw(Exporter);

@EXPORT = qw(task desc group 
            user password public_key private_key pass_auth no_ssh
            get_random do_task batch timeout parallelism
            exit
            evaluate_hostname
            logging
            needs
            say
            LOCAL
          );

=item no_ssh([$task])

Disable ssh for all tasks or a specified task.

If you want to disable ssh connection for your complete tasks (for example if you only want to use libVirt) put this in the main section of your Rexfile.

 no_ssh;

If you want to disable ssh connection for a given task, put I<no_ssh> in front of the task definition.

 no_ssh task "mytask", "myserver", sub {
    say "Do something without a ssh connection";
 };

=cut

sub no_ssh {
   if(@_) {
      $_[0]->(no_ssh => 1);
   }
   else {
      $global_no_ssh = 1;
   }
}

=item task($name [, @servers], $funcref)

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
   my($class, $file, @tmp) = caller;
   my @_ARGS = @_;

   if(wantarray) {
      return sub {
         my %option = @_;

         $option{class} = $class;
         $option{file}  = $file;
         $option{tmp}   = \@tmp;

         task(@_ARGS,\%option);
      };
   }

   if(ref($_ARGS[-1]) eq "HASH") {
      if($_ARGS[-1]->{class}) {
         $class = $_ARGS[-1]->{class};
      }

      if($_ARGS[-1]->{file}) {
         $file = $_ARGS[-1]->{file};
      }

      if($_ARGS[-1]->{tmp}) {
         @tmp = @{ $_ARGS[-1]->{tmp} };
      }
   }

   my $task_name = shift;
   my $task_name_save = $task_name;

   my $options = {};

   if(ref($_[-1]) eq "HASH") {
      $options = pop;
   }

   if($global_no_ssh) {
      $options->{"no_ssh"} = 1;
   }

   if($class ne "main") {
      $task_name = $class . ":" . $task_name;
   }

   $task_name =~ s/^Rex:://;
   $task_name =~ s/::/:/g;

   if($current_desc) {
      push(@_, $current_desc);
      $current_desc = "";
   }
   else {
      push(@_, "");
   }

   no strict 'refs';
   no warnings;
   push (@{"${class}::tasks"}, { name => $task_name_save, code => $_[-2] } );
   use strict;
   use warnings;

   Rex::Task->create_task($task_name, @_, $options);
}

=item desc($description)

Set the description of a task.

 desc "This is a task description of the following task";
 task "mytask", sub {
    say "Do something";
 }

=cut

sub desc {
   $current_desc = shift;
}

=item group($name, @servers)

With this function you can group servers, so that you don't need to write too much ;-)

 group "servergroup", "www1", "www2", "www3", "memcache01", "memcache02", "memcache03";

Or with the expression syntax.

 group "servergroup", "www[1..3]", "memcache[01..03]";

=cut

sub group {
   Rex::Group->create_group(@_);
}

=item batch($name, @tasks)

With the batch function you can call tasks in a batch.

 batch "name", "task1", "task2", "task3";

And call it with the I<-b> console parameter. I<rex -b name>

=cut

sub batch {
   if($current_desc) {
      push(@_, $current_desc);
      $current_desc = "";
   }
   else {
      push(@_, "");
   }

   Rex::Batch->create_batch(@_);
}

=item user($user)

Set the user for the ssh connection.

=cut

sub user {
   Rex::Config->set_user(@_);
}

=item password($password)

Set the password for the ssh connection (or for the private key file).

=cut

sub password {
   Rex::Config->set_password(@_);
}

=item timeout($seconds)

Set the timeout for the ssh connection and other network related stuff.

=cut

sub timeout {
   Rex::Config->set_timeout(@_);
}

=item get_random($count, @chars)

Returns a random string of $count characters on the basis of @chars.

 my $rnd = get_random(8, 'a' .. 'z');

=cut

sub get_random {
	my $count = shift;
	my @chars = @_;
	
	srand();
	my $ret = "";
	for(0..$count) {
		$ret .= $chars[int(rand(scalar(@chars)-1))];
	}
	
	return $ret;
}

=item do_task($task)

Call $task from an other task. Will execute the given $task with the servers defined in $task.

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
   my $task = shift;

   if(ref($task) eq "ARRAY") {
      for my $t (@{$task}) {
         Rex::Task->run($t);
      }
   }
   else {
      return Rex::Task->run($task);
   }
}

=item public_key($key)

Set the public key.

=cut

sub public_key {
   Rex::Config->set_public_key(@_);
}

=item private_key($key)

Set the private key.

=cut

sub private_key {
   Rex::Config->set_private_key(@_);
}

=item pass_auth

If you want to user password authentication, then you need to call I<pass_auth>.

 user "root";
 password "root";
 
 pass_auth;

=cut

sub pass_auth {
   Rex::Config->set_password_auth(1);
}

=item parallelism($count)

Will execute the tasks in parallel on the given servers. $count is the thread count to be used.

=cut

sub parallelism {
   Rex::Config->set_parallelism($_[0]);
}

=item logging

With this function you can define the logging behaviour of (R)?ex.

=over 4

=item Logging to a file

 logging to_file => "rex.log";

=item Logging to syslog

 logging to_syslog => $facility;

=back

=cut

sub logging {
   my $args = { @_ };

   if(exists $args->{'to_file'}) {
      Rex::Config->set_log_filename($args->{'to_file'});
   }
   elsif(exists $args->{'to_syslog'}) {
      Rex::Config->set_log_facility($args->{'to_syslog'});
   }
   else {
      Rex::Config->set_log_filename('rex.log');
   }
}

=item needs($package [, @tasks])

With I<needs> you can define dependencies between tasks. The "needed" tasks will be called with the same server configuration as the calling task.

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

=back

=cut

sub needs {
   my ($self, @args) = @_;

   Rex::Logger::debug("need to call tasks from $self");

   no strict 'refs';
   my @tasks_to_run = @{"${self}::tasks"};
   use strict;

   # cli parameter auslesen
   # damit man sie dem task mitgeben kann
   my @params = @ARGV[1..$#ARGV];
   my %opts = ();
   for my $p (@params) {
      my($key, $val) = split(/=/, $p, 2);
      $key = substr($key, 2);

      if($val) { $opts{$key} = $val; next; }
      $opts{$key} = 1;
   }

   for my $task (@tasks_to_run) {
      my $task_name = $task->{"name"};
      if(@args && grep (/^$task_name$/, @args)) {
         Rex::Logger::debug("Calling " . $task->{"name"});
         &{ $task->{"code"} }(\%opts);
      }
      elsif(! @args) {
         Rex::Logger::debug("Calling " . $task->{"name"});
         &{ $task->{"code"} }(\%opts);
      }
   }

}

=item LOCAL(&)

With the LOCAL function you can do local commands within a task that is defined to work on remote servers.

 task "mytask", "server1", "server2", sub {
     # this will call 'uptime' on the servers 'server1' and 'server2'
     say run "uptime";
     
     # this will call 'uptime' on the local machine.
     LOCAL {
        say run "uptime";
     };
 };

=cut

sub LOCAL (&) {
   my $cur_conn = Rex::get_current_connection();
   Rex::push_connection({ssh => 0, server => $cur_conn->{"server"}});
   $_[0]->();
   Rex::pop_connection();
}

=back

=cut

######### private functions

sub evaluate_hostname {
   my $str = shift;

   my ($start, $from, $to, $dummy, $step, $end) = $str =~ m/^([\w-]+)\[(\d+)..(\d+)(\/(\d+))?\]([\w\.-]+)?$/;

   unless($start) {
      return $str;
   }

   $end  ||= '';
   $step ||= 1;

   my $strict_length = 0;
   if( length $from == length $to ) {
      $strict_length = length $to;
   }

   my @ret = ();
   for(; $from <= $to; $from += $step) {
         my $format = "%0".$strict_length."i";
         push @ret, $start . sprintf($format, $from) . $end;
   }

   return @ret;
}

sub exit {
   Rex::Logger::info("Exiting Rex...");
   Rex::Logger::info("Cleaning up...");

   unlink("$::rexfile.lock") if($::rexfile);

   CORE::exit(@_);
}



sub say {
   print @_, "\n";
}

1;
