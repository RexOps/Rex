#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::TaskList::Base;
   
use strict;
use warnings;

use Data::Dumper;
use Rex::Logger;
use Rex::Task;
use Rex::Config;
use Rex::Interface::Executor;
use Rex::Fork::Manager;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   $self->{IN_TRANSACTION} = 0;
   $self->{DEFAULT_AUTH} = 1;
   $self->{tasks} = {};

   return $self;
}

sub create_task {
   my $self     = shift;
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

      if($::FORCE_SERVER =~ m/^\0/) {
         push(@server, map { Rex::Group::Entry::Server->new(name => $_); } Rex::Group->get_group(substr($::FORCE_SERVER, 1)));
      }
      else {
         my @servers = split(/\s+/, $::FORCE_SERVER);
         push(@server, map { Rex::Group::Entry::Server->new(name => $_); } @servers);

         Rex::Logger::debug("\tserver: $_") for @server;
      }

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
                  push(@server, Rex::Group->get_group($group));
               }
            }
         }
         else {
            for my $entry (@_) {
               push(@server, Rex::Group::Entry::Server->new(name => $entry));
            }
         }
      }

   }

   my %task_hash = (
      func => $func,
      server => [ @server ],
      desc => $desc,
      no_ssh => ($options->{"no_ssh"}?1:0),
      hidden => ($options->{"dont_register"}?1:0),
      before => [],
      after  => [],
      around => [],
      name => $task_name,
      executor => Rex::Interface::Executor->create,
      connection_type => Rex::Config->get_connection_type,
   );

   if($self->{DEFAULT_AUTH}) {
      $task_hash{auth} = {
         user        => Rex::Config->get_user,
         password    => Rex::Config->get_password,
         private_key => Rex::Config->get_private_key,
         public_key  => Rex::Config->get_public_key,
         sudo_password => Rex::Config->get_sudo_password,
      };
   }

   $self->{tasks}->{$task_name} = Rex::Task->new(%task_hash);

}


sub get_tasks {
   my $self = shift;
   return grep { $self->{tasks}->{$_}->hidden() == 0 } sort { $a cmp $b } keys %{ $self->{tasks} };
}

sub get_tasks_for {
   my $self = shift;
   my $host = shift;

   my @tasks;
   for my $task_name (keys %{ $self->{tasks} }) {
      my @servers = @{ $self->{tasks}->{$task_name}->server() };

      if( (grep { /^$host$/ } @servers) || $#servers == -1) {
         push @tasks, $task_name;
      }
   }

   return sort { $a cmp $b } @tasks;
}

sub get_task {
   my ($self, $task) = @_;
   return $self->{tasks}->{$task};
}

sub clear_tasks {
   my $self = shift;
   $self->{tasks} = {};
}

sub get_desc {
   my $self = shift;
   my $task = shift;

   return $self->{tasks}->{$task}->desc();
}

sub is_task {
   my $self = shift;
   my $task = shift;
   
   if(exists $self->{tasks}->{$task}) { return 1; }
   return 0;
}

sub run {
   my ($self, $task_name, %option) = @_;
   my $task = $self->get_task($task_name);

   $option{params} ||= { Rex::Args->get };


   my @all_server = @{ $task->server };

   my $fm = Rex::Fork::Manager->new(max => $task->parallelism || Rex::Config->get_parallelism);

   for my $server (@all_server) {

      my $forked_sub = sub {

         Rex::Logger::init();

         # create a single task object for the run on $server

         my $run_task = Rex::Task->new( %{$task->get_data} );

         $run_task->run($server,
                     in_transaction => $self->{IN_TRANSACTION},
                     params => $option{params});

         Rex::Logger::shutdown();

      };

      # add the worker (forked_sub) to the fork queue
      unless($self->{IN_TRANSACTION}) {
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
   my ($self, $type, $task, $code, $package, $file, $line) = @_;

   if($package ne "main" && $package ne "Rex::CLI") {
      if($task !~ m/:/) {
         #do we need to detect for base -Rex ?
         $package =~ s/^Rex:://;
         $package =~ s/::/:/g;
         $task = $package . ":" . $task;
      }
   }

   my $taskref = $self->get_task($task);
   if (defined($taskref)) {
      $taskref->modify($type => $code);
   } else {
      Rex::Logger::info("can't add $type $task, as its not yet defined\nsee $file line $line");
   }
}

sub set_default_auth {
   my ($self, $auth) = @_;
   $self->{DEFAULT_AUTH} = $auth;
}

sub is_default_auth {
   my ($self) = @_;
   return $self->{DEFAULT_AUTH};
}

sub set_in_transaction {
   my ($self, $val) = @_;
   $self->{IN_TRANSACTION} = $val;
}

sub is_transaction {
   my ($self) = @_;
   return $self->{IN_TRANSACTION};
}

1;
