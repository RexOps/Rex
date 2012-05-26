#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::TaskList;
   
use strict;
use warnings;

use Data::Dumper;
use Rex::Logger;
use Rex::Task;
use Rex::Config;
use Rex::Interface::Executor;
use Rex::Fork::Manager;

use vars qw(%tasks);

# will be set from Rex::Transaction::transaction()
our $IN_TRANSACTION = 0;

sub create_task {
   my $class     = shift;
   my $task_name = shift;
   my $options   = pop;
   my $desc      = pop;

   Rex::Logger::debug("Creating task: $task_name");

   my $func;
   if(ref($desc) eq "CODE") {
      $func = $desc;
      $desc = "";
   } else {
      $func = pop;
   }

   my @server = ();

   if($::FORCE_SERVER) {

      $::FORCE_SERVER = join(" ", Rex::Group->get_group(substr($::FORCE_SERVER, 1))) if($::FORCE_SERVER =~ m/^\0/);

      my @servers = split(/\s+/, $::FORCE_SERVER);
      push @server, Rex::Commands::evaluate_hostname($_) for @servers;

      Rex::Logger::debug("\tserver: $_") for @server;

   }

   else {

      if(scalar(@_) >= 1) {
         if($_[0] eq "group") {
            my $groups;
            if(ref($_[1]) eq "ARRAY") {
               $groups = $_[1];
            }
            else {
               $groups = [ $_[1] ];
            }
            
            for my $group (@{$groups}) {
               if(Rex::Group->is_group($group)) {
                  Rex::Logger::debug("\tusing group: $group -> " . join(", ", Rex::Group->get_group($group)));

                  for my $server_name (Rex::Group->get_group($group)) {
                     if(ref($server_name) eq "CODE") {
                        push(@server, $server_name);
                     }
                     else {
                        push(@server, Rex::Commands::evaluate_hostname($server_name));
                     }
                  }

                  Rex::Logger::debug("\tserver: $_") for @server;
               } else {
                  Rex::Logger::info("Group $group not found!");
                  exit 1;
               }
            }
         } else {
            push @server, Rex::Commands::evaluate_hostname($_) for @_;
            Rex::Logger::debug("\tserver: $_") for @server;
         }
      }

   }

   $tasks{$task_name} = Rex::Task->new(
      func => $func,
      server => [ @server ],
      desc => $desc,
      no_ssh => ($options->{"no_ssh"}?1:0),
      hidden => ($options->{"dont_register"}?1:0),
      auth => {
         user        => Rex::Config->get_user,
         password    => Rex::Config->get_password,
         private_key => Rex::Config->get_private_key,
         public_key  => Rex::Config->get_public_key,
      },
      before => [],
      after  => [],
      around => [],
      name => $task_name,
      executor => Rex::Interface::Executor->create,
   );

}


sub get_tasks {
   my $class = shift;
   return grep { $tasks{$_}->hidden() == 0 } sort { $a cmp $b } keys %tasks;
}

sub get_tasks_for {
   my $class = shift;
   my $host = shift;

   my @tasks;
   for my $task_name (keys %tasks) {
      my @servers = @{ $tasks{$task_name}->server() };

      if( (grep { /^$host$/ } @servers) || $#servers == -1) {
         push @tasks, $task_name;
      }
   }

   return sort { $a cmp $b } @tasks;
}

sub get_task {
   my ($class, $task) = @_;
   return $tasks{$task};
}

sub clear_tasks {
   my $class = shift;
   %tasks = ();
}

sub get_desc {
   my $class = shift;
   my $task = shift;

   return $tasks{$task}->desc();
}

sub is_task {
   my $class = shift;
   my $task = shift;
   
   if(exists $tasks{$task}) { return 1; }
   return 0;
}

sub run {
   my ($class, $task_name) = @_;
   my $task = $class->get_task($task_name);

   my @all_server = @{ $task->server };

   my $fm = Rex::Fork::Manager->new(max => Rex::Config->get_parallelism);

   for my $server (@all_server) {

      my $forked_sub = sub {

         Rex::Logger::init();

         # create a single task object for the run on $server

         my $run_task = Rex::Task->new( %{$task->get_data} );

         $run_task->run($server,
                     in_transaction => $IN_TRANSACTION,);

         Rex::Logger::shutdown();

      };

      # add the worker (forked_sub) to the fork queue
      unless($IN_TRANSACTION) {
         # not inside a transaction, so lets fork happyly...
         $fm->add($forked_sub, 1);
      }
      else {
         # inside a transaction, no little small funny kids, ... and no chance to get zombies :(
         &$forked_sub();
      }

   }

   Rex::Logger::debug("Waiting for children to finish");
   $fm->wait_for_all;
}

sub modify {
   my ($class, $type, $task, $code, $package, $file, $line) = @_;

   if($package ne "main") {
      if($task !~ m/:/) {
         #do we need to detect for base -Rex ?
         $package =~ s/^Rex:://;
         $package =~ s/::/:/g;
         $task = $package . ":" . $task;
      }
   }

   my $taskref = Rex::TaskList->get_task($task);
   if (defined($taskref)) {
      $taskref->modify($type => $code);
   } else {
      Rex::Logger::info("can't add $type $task, as its not yet defined\nsee $file line $line");
   }
}


1;
