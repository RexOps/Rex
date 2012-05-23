#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Task;

use strict;
use warnings;
use Net::SSH2;
use Rex::Group;
use Rex::Fork::Manager;
use Rex::Cache;
use Rex::Interface::Connection;
use Sys::Hostname;
use Rex::Output;

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

   $tasks{$task_name} = {
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
   };

}

sub modify_task {
   my $class = shift;
   my $task  = shift;
   my $key   = shift;
   my $value = shift;

   if(ref($tasks{$task}->{$key}) eq "ARRAY") {
      push(@{ $tasks{$task}->{$key} }, $value);
   }
   elsif(ref($tasks{$task}->{$key}) eq "HASH") {
      @{$tasks{$task}->{$key}}{keys(%$value)} = values(%$value);
   }
   else {
      $tasks{$task}->{$key} = $value;
   }
}

sub get_tasks {
   my $class = shift;

   return grep { $tasks{$_}->{hidden} == 0 } sort { $a cmp $b } keys %tasks;
}

sub get_tasks_for {
   my $class = shift;
   my $host = shift;

   my @tasks;
   for my $task_name (keys %tasks) {
      my @servers = @{$tasks{$task_name}->{"server"}};

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

   return $tasks{$task}->{"desc"};
}

sub is_task {
   my $class = shift;
   my $task = shift;
   
   if(exists $tasks{$task}) { return 1; }
   return 0;
}

sub run {
   my $class = shift;
   my $task = shift;
   my $server_overwrite = shift;
   my $params = shift;

   my $ret;

   # get servers belonging to the task
   my @server = @{$tasks{$task}->{'server'}};
   Rex::Logger::debug("\tserver: $_") for @server;

   my @new_server;
   for my $server_name (@server) {
      if(ref($server_name) eq "CODE") {
         push(@new_server, &$server_name());
      }
      else {
         push(@new_server, $server_name);
      }
   }

   @server = @new_server;
   
   # overwrite servers if requested
   # this is mostly for the rex agent
   if($server_overwrite) {
      if($server_overwrite eq "<local>") {
         @server = ();
      }
      else {
         @server = ($server_overwrite);
      }
   }
   Rex::Logger::info("Running task: $task on: ".join(',', @server));

   my($user, $pass, $private_key, $public_key);
   if(ref($server[-1]) eq "HASH") {
      # use extra defined credentials
      my $data = pop(@server);
      $user = $data->{'user'};
      $pass = $data->{'password'};
      if(exists $data->{"private_key"}) {
         $private_key = $data->{"private_key"};
         $public_key  = $data->{"public_key"};
      }
   } else {
      $user        = $tasks{$task}->{"auth"}->{"user"};
      $pass        = $tasks{$task}->{"auth"}->{"password"};
      $private_key = $tasks{$task}->{"auth"}->{"private_key"};
      $public_key  = $tasks{$task}->{"auth"}->{"public_key"};
   }

   $user ||= "";
   Rex::Logger::debug("Using user: $user");
   Rex::Logger::debug("Using password: " . ($pass?"***********":"<no password>"));

   my $timeout = Rex::Config->get_timeout;

   # parse cli parameter in the form
   #    --key=value or --key
   my @params = @ARGV[1..$#ARGV];
   my %opts = ();
   for my $p (@params) {
      my($key, $val) = split(/=/, $p, 2);
      $key = substr($key, 2);

      if($val) { $opts{$key} = $val; next; }
      $opts{$key} = 1;
   }

   if($params) {
      %opts = %{$params};
   }

   # get hostname
   my $hostname = hostname();
   my ($shortname) = ($hostname =~ m/^([^\.]+)\.?/);
   Rex::Logger::debug("My Hostname: " . $hostname);
   Rex::Logger::debug("My Shortname: " . $shortname);

   if(scalar(@server) > 0) {
      # task should not run lokal

      my @children;

      # create fork manager object
      my $fm = Rex::Fork::Manager->new(max => Rex::Config->get_parallelism);

      # iterate over the server and push the worker function to the fork manager's queue
      for my $server (@server) {
         Rex::Logger::debug("Next Server: $server");
         # push it
         my $forked_sub = sub {
            my $conn;

            # reconnect to logger
            Rex::Logger::init();

            # before jobs
            for my $code (@{$tasks{$task}->{"before"}}) {
               &$code($server, \$server, \%opts);
            }

            # around jobs
            for my $code (@{$tasks{$task}->{"around"}}) {
               &$code($server, 0, \%opts);
            }

            # this must be a ssh/remote connection

            my $conn_type = "SSH";
            if($tasks{$task}->{"no_ssh"}) {
               $conn_type = "Fake";
            }

            $conn = Rex::Interface::Connection->create($conn_type);

            $conn->connect(
               user     => $user,
               password => $pass,
               server   => $server
            );

            unless($conn->is_connected) {
               CORE::exit(1);
            }

            # push a remote connection
            Rex::push_connection({
               conn   => $conn, 
               ssh    => $conn->get_connection_object, 
               server => $server, 
               cache => Rex::Cache->new(),
            });

            # auth unsuccessfull
            unless($conn->is_authenticated) {
               Rex::Logger::info("Wrong username or password. Or wrong key.", "warn");
               # after jobs
               for my $code (@{$tasks{$task}->{"after"}}) {
                  &$code($server, 1, %opts);
               }


               CORE::exit 1;
            }

            Rex::Logger::debug("Successfull auth");

            # run the task
            $ret = _exec($task, \%opts);

            # around jobs
            for my $code (@{$tasks{$task}->{"around"}}) {
               &$code($server, 1, \%opts);
            }

            # disconnect if ssh connection
            if(! $tasks{$task}->{"no_ssh"} && $server ne "localhost" && $server ne $shortname) {
               Rex::Logger::debug("Disconnecting from $server");
               $conn->disconnect() unless($IN_TRANSACTION);
            }

            # remove remote connection from the stack
            Rex::pop_connection();

            # after jobs
            for my $code (@{$tasks{$task}->{"after"}}) {
               &$code($server, 0, \%opts);
            }

            # close logger
            Rex::Logger::shutdown();

         }; # [END] $forked_sub

         # add the worker (forked_sub) to the fork queue
         unless($IN_TRANSACTION) {
            # not inside a transaction, so lets fork happyly...
            $fm->add($forked_sub, 1);
         }
         else {
            # inside a transaction, no little small funny kids, ... and no chance to get zombies :(
            &$forked_sub();
         }
      } # [END] for my $server

      Rex::Logger::debug("Waiting for children to finish");
      # wait for all jobs to be finished
      $fm->wait_for_all;

   } else {

      Rex::Logger::init();
      
      my $server = '<local>';

      # before jobs
      for my $code (@{$tasks{$task}->{"before"}}) {
         &$code($server, \$server, \%opts);
      }

      # around jobs
      for my $code (@{$tasks{$task}->{"around"}}) {
         &$code($server, 0, \%opts);
      }

      my $conn = Rex::Interface::Connection->create("Local");

      $conn->connect();


      Rex::Logger::debug("This is not a remote session");
      # push a local connection
      Rex::push_connection({
         conn   => $conn,
         ssh    => 0,
         server => $server,
         cache  => Rex::Cache->new(),
      });

      $ret = _exec($task, \%opts);

      # around jobs
      for my $code (@{$tasks{$task}->{"around"}}) {
         &$code($server, 1, \%opts);
      }

      # remove local connection from stack
      Rex::pop_connection();

      # around jobs
      for my $code (@{$tasks{$task}->{"after"}}) {
         &$code($server, 0, \%opts);
      }

      Rex::Logger::shutdown();
   }

   return $ret;
}

sub _exec {
   my $task = shift;
   my $opts = shift;

   Rex::Logger::debug("Executing $task");

   my $ret;
   eval {
      my $code = $tasks{$task}->{'func'};
      $ret = &$code($opts);
   };

   if($@) {
      if(Rex::Output->get) {
         Rex::Output->get->add($task, error => 1, msg => $@);
      }
      else {
         die($@);
      }
   }
   else {
      if(Rex::Output->get) {
         Rex::Output->get->add($task);
      }
   }

   return $ret;
}

1;
