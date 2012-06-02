#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
=head1 NAME

Rex::Task - The Task Object

=head1 DESCRIPTION

The Task Object. Typically you only need this class if you want to manipulate tasks after their initial creation.

=head1 SYNOPSIS

 use Rex::Task
     
  my $task = Rex::Task->new(name => "testtask");
  $task->set_server("remoteserver");
  $task->set_code(sub { say "Hello"; });
  $task->modify("no_ssh", 1);

=head1 METHODS

=over 4

=cut
package Rex::Task;

use strict;
use warnings;
use Data::Dumper;

use Rex::Logger;
use Rex::TaskList;
use Rex::Interface::Connection;
use Rex::Interface::Executor;

require Rex::Args;

=item new

This is the constructor.

   $task = Rex::Task->new(
      func => sub { some_code_here },
      server => [ @server ],
      desc => $description,
      no_ssh => $no_ssh,
      hidden => $hidden,
      auth => {
         user        => $user,
         password    => $password,
         private_key => $private_key,
         public_key  => $public_key,
      },
      before => [sub {}, sub {}, ...],
      after  => [sub {}, sub {}, ...],
      around => [sub {}, sub {}, ...],
      name => $task_name,
      executor => Rex::Interface::Executor->create,
   );


=cut
sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   if(! exists $self->{name}) {
      die("You have to define a task name.");
   }

   $self->{no_ssh} ||= 0;
   $self->{func}   ||= sub {};
   $self->{executor} ||= Rex::Interface::Executor->create;

   $self->{connection} = undef;

   return $self;
}

=item connection

Returns the current connection object.

=cut
sub connection {
   my ($self) = @_;

   if(! exists $self->{connection} || ! $self->{connection}) {
      $self->{connection} = Rex::Interface::Connection->create($self->get_connection_type);
   }

   $self->{connection};
}

=item executor

Returns the current executor object.

=cut
sub executor {
   my ($self) = @_;
   $self->{executor}->set_task($self);
   return $self->{executor};
}

=item hidden

Returns true if the task is hidden. (Should not be displayed on ,,rex -T''.)

=cut
sub hidden {
   my ($self) = @_;
   return $self->{hidden};
}

=item server

Returns the servers on which the task should be executed as an ArrayRef.

=cut
sub server {
   my ($self) = @_;

   my @server = @{ $self->{server} };
   my @ret = ();

   if(ref($server[-1]) eq "HASH") {
      Rex::deprecated(undef, "0.40", "Defining extra credentials within the task creation is deprecated.",
                                     "Please use set auth => task => 'taskname' instead.");

      # use extra defined credentials
      my $data = pop(@server);
      $self->set_auth("user", $data->{'user'});
      $self->set_auth("password", $data->{'password'});

      if(exists $data->{"private_key"}) {
         $self->set_auth("private_key", $data->{"private_key"});
         $self->set_auth("public_key", $data->{"public_key"});
      }
   }

   if(ref($self->{server}) eq "ARRAY" && scalar(@{ $self->{server} }) > 0) {
      for my $srv (@{ $self->{server} }) {
         if(ref($srv) eq "CODE") {
            push(@ret, &$srv());
         }
         else {
            push(@ret, $srv);
         }
      }
   }
   elsif(ref($self->{server}) eq "CODE") {
      push(@ret, &{ $self->{server} }());
   }
   else {
      push(@ret, "<local>");
   }

   return [@ret];
}

=item set_server(@server)

With this method you can set new servers on which the task should be executed on.

=cut
sub set_server {
   my ($self, @server) = @_;
   $self->{server} = \@server;
}

=item delete_server

Delete every server registered to the task.

=cut
sub delete_server {
   my ($self) = @_;
   delete $self->{current_server};
   delete $self->{server};
   $self->rethink_connection;
}

=item current_server

Returns the current server on which the tasks gets executed right now.

=cut
sub current_server {
   my ($self) = @_;
   return $self->{current_server} || "<local>";
}

=item desc

Returns the description of a task.

=cut
sub desc {
   my ($self) = @_;
   return $self->{desc};
}

=item set_desc($description)

Set the description of a task.

=cut
sub set_desc {
   my ($self, $desc) = @_;
   $self->{desc} = $desc;
}

=item is_remote

Returns true (1) if the task will be executed remotely.

=cut
sub is_remote {
   my ($self) = @_;
   if(exists $self->{current_server}) {
      if($self->{current_server} ne '<local>') {
         return 1;
      }
   } else {
      if(exists $self->{server} && scalar(@{ $self->{server} }) > 0) {
         return 1;
      }
   }

   return 0;
}

=item is_local

Returns true (1) if the task gets executed on the local host.

=cut
sub is_local {
   my ($self) = @_;
   return $self->is_remote() == 0 ? 1 : 0;
}

=item want_connect

Returns true (1) if the task will establish a connection to a remote system.

=cut
sub want_connect {
   my ($self) = @_;
   return $self->{no_ssh} == 0 ? 1 : 0;
}

=item get_connection_type

This method tries to guess the right connection type for the task and returns it.

Current return values are SSH, Fake and Local. 

SSH - will create a ssh connection to the remote server

Local - will not create any connections

Fake - will not create any connections. But it populates the connection properties so you can use this type to iterate over a list of remote hosts but don't let rex build a connection. For example if you want to use Sys::Virt or other modules.

=cut
sub get_connection_type {
   my ($self) = @_;

   if($self->is_remote && $self->want_connect) {
      return "SSH";
   }
   elsif($self->is_remote) {
      return "Fake";
   }
   else {
      return "Local";
   }
}

=item modify($key, $value)

With this method you can modify values of the task.

=cut
sub modify {
   my ($self, $key, $value) = @_;

   if(ref($self->{$key}) eq "ARRAY") {
      push(@{ $self->{$key} }, $value);
   }
   else {
      $self->{$key} = $value;
   }

   $self->rethink_connection;
}

sub rethink_connection {
   my($self) = @_;
   delete $self->{connection};
   $self->connection;
}

=item user

Returns the current user the task will use.

=cut
sub user {
   my ($self) = @_;
   if(exists $self->{auth} && $self->{auth}->{user}) {
      return $self->{auth}->{user};
   }
}

=item set_user($user)

Set the user of a task.

=cut
sub set_user {
   my ($self, $user) = @_;
   $self->{auth}->{user} = $user;
}

=item password

Returns the password that will be used.

=cut
sub password {
   my ($self) = @_;
   if(exists $self->{auth} && $self->{auth}->{password}) {
      return $self->{auth}->{password};
   }
}

=item set_password($password)

Set the password of the task.

=cut
sub set_password {
   my ($self, $password) = @_;
   $self->{auth}->{password} = $password;
}

=item name

Returns the name of the task.

=cut
sub name {
   my ($self) = @_;
   return $self->{name};
}

=item code

Returns the code of the task.

=cut
sub code {
   my ($self) = @_;
   return $self->{func};
}

=item set_code(\&code_ref)

Set the code of the task.

=cut
sub set_code {
   my ($self, $code) = @_;
   $self->{func} = $code;
}

=item run_hook($server, $hook)

This method is used internally to execute the specified hooks.

=cut
sub run_hook {
   my ($self, $server, $hook) = @_;

   for my $code (@{ $self->{$hook} }) {
      if($hook eq "after") { # special case for after hooks
         &$code($$server, ($self->{"__was_authenticated"} ? undef : 1), { Rex::Args->get });
      }
      else {
         my $old_server = $$server if $server;
         &$code($$server, $server, { Rex::Args->get });
         if($old_server && $old_server ne $$server) {
            $self->{current_server} = $$server;
         }
      }
   }
}

=item set_auth($key, $value)

Set the authentication of the task.

 $task->set_auth("user", "foo");
 $task->set_auth("password", "bar");

=cut
sub set_auth {
   my ($self, $key, $value) = @_;
   $self->{auth}->{$key} = $value;
}

=item connect($server)

Initiate the connection to $server.

=cut
sub connect {
   my ($self, $server) = @_;

   $self->{current_server} = $server;

   Rex::Logger::debug("Using user: " . $self->user);
   Rex::Logger::debug("Using password: " . ($self->password?"***********":"<no password>"));

   $self->connection->connect(
      user     => $self->user,
      password => $self->password,
      server   => $server,
   );

   if($self->connection->is_authenticated) {
      Rex::Logger::info("Successfull authenticated.");
      $self->{"__was_authenticated"} = 1;
   }
   else {
      Rex::Logger::info("Wrong username or password. Or wrong key.", "warn");
      CORE::exit(1);
   }

   # need to get rid of this
   Rex::push_connection({
         conn   => $self->connection, 
         ssh    => $self->connection->get_connection_object, 
         server => $server, 
         cache => Rex::Cache->new(),
   });

   $self->run_hook(\$server, "around");

}

=item disconnect

Disconnect from the current connection.

=cut
sub disconnect {
   my ($self, $server) = @_;

   $self->run_hook(\$server, "around");
   $self->connection->disconnect;

   delete $self->{connection};

   # need to get rid of this
   Rex::pop_connection();
}

sub get_data {
   my ($self) = @_;

   return {
      func => $self->{func},
      server => $self->{server},
      desc => $self->{desc},
      no_ssh => $self->{no_ssh},
      hidden => $self->{hidden},
      auth => $self->{auth},
      before => $self->{before},
      after  => $self->{after},
      around => $self->{around},
      name => $self->{name},
      executor => $self->{executor},
   };
}

#####################################
# deprecated functions
# for compatibility
#####################################

=begin run($server, %options)

Run the task on $server.

=cut
sub run {
   # someone used this function directly... bail out


   if(ref($_[0])) {
      my ($self, $server, %options) = @_;

      if(! $_[1]) {
         # run is called without any server.
         # so just connect to any servers.
         return Rex::TaskList->run($self->name, %options);
      }

      # this is a method call
      # so run the task

      my $in_transaction = $options{in_transaction};
      
      $self->run_hook(\$server, "before");
      $self->connect($server);

      # execute code
      my $ret = $self->executor->exec($options{params});

      $self->disconnect($server) unless($in_transaction);
      $self->run_hook(\$server, "after");

      return $ret;
   }

   else {
      my ($class, $task, $server_overwrite, $params) = @_;
      Rex::deprecated("Rex::Task->run()", "0.40");

      if($server_overwrite) {
         Rex::TaskList->get_task($task)->set_server($server_overwrite);
      }

      # this is a deprecated static call
      Rex::TaskList->run($task, params => $params);
   }
}

sub modify_task {
   my $class = shift;
   my $task  = shift;
   my $key   = shift;
   my $value = shift;

   Rex::TaskList->get_task($task)->modify($key => $value);
}

sub is_task {
   my ($class, $task) = @_;
   return Rex::TaskList->is_task($task);
}

sub get_tasks {
   my ($class, @tmp) = @_;
   return Rex::TaskList->get_tasks(@tmp);
}

sub get_desc {
   my ($class, @tmp) = @_;
   return Rex::TaskList->get_desc(@tmp);
}

=back

=cut

1;
