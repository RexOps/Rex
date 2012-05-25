#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Task;

use strict;
use warnings;
use Data::Dumper;

use Rex::Logger;
use Rex::TaskList;
use Rex::Interface::Connection;
use Rex::Interface::Executor;

require Rex::Args;

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

   return $self;
}

sub connection {
   my ($self) = @_;

   if(! exists $self->{connection}) {
      $self->{connection} = Rex::Interface::Connection->create($self->get_connection_type);
   }

   $self->{connection};
}

sub executor {
   my ($self) = @_;
   $self->{executor}->set_task($self);
   return $self->{executor};
}

sub hidden {
   my ($self) = @_;
   return $self->{hidden};
}

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

sub set_server {
   my ($self, @server) = @_;
   $self->{server} = \@server;
}

sub current_server {
   my ($self) = @_;
   return $self->{current_server};
}

sub desc {
   my ($self) = @_;
   return $self->{desc};
}

sub set_desc {
   my ($self, $desc) = @_;
   $self->{desc} = $desc;
}

sub is_remote {
   my ($self) = @_;
   if(exists $self->{server} && scalar(@{ $self->{server} }) > 0) {
      return 1;
   }

   return 0;
}

sub is_local {
   my ($self) = @_;
   return $self->is_remote() == 0 ? 1 : 0;
}

sub want_connect {
   my ($self) = @_;
   return $self->{no_ssh} == 0 ? 1 : 0;
}

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

sub modify {
   my ($self, $key, $value) = @_;

   if(ref($self->{$key}) eq "ARRAY") {
      push(@{ $self->{$key} }, $value);
   }
   else {
      $self->{$key} = $value;
   }

   if($key eq "no_ssh") {
      delete $self->{connection};
      $self->connection;
   }
}

sub user {
   my ($self) = @_;
   if(exists $self->{auth} && $self->{auth}->{user}) {
      return $self->{auth}->{user};
   }
}

sub set_user {
   my ($self, $user) = @_;
   $self->{auth}->{user} = $user;
}

sub password {
   my ($self) = @_;
   if(exists $self->{auth} && $self->{auth}->{password}) {
      return $self->{auth}->{password};
   }
}

sub set_password {
   my ($self, $password) = @_;
   $self->{auth}->{password} = $password;
}

sub name {
   my ($self) = @_;
   return $self->{name};
}

sub code {
   my ($self) = @_;
   return $self->{func};
}

sub set_code {
   my ($self, $code) = @_;
   $self->{func} = $code;
}

sub run_hook {
   my ($self, $server, $hook) = @_;

   for my $code (@{ $self->{$hook} }) {
      if($hook eq "after") { # special case for after hooks
         &$code($$server, ($self->connection->is_authenticated ? undef : 1));
      }
      else {
         &$code($$server, $server, { Rex::Args->get });
      }
   }
}

sub set_auth {
   my ($self, $key, $value) = @_;
   $self->{auth}->{$key} = $value;
}

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

sub disconnect {
   my ($self, $server) = @_;

   $self->run_hook(\$server, "around");
   $self->connection->disconnect;

   # need to get rid of this
   Rex::pop_connection();
}

#####################################
# deprecated functions
# for compatibility
#####################################

sub run {
   # someone used this function directly... bail out


   if(ref($_[0])) {
      my ($self, $server, %options) = @_;

      if(! $_[1]) {
         # run is called without any server.
         # so just connect to any servers.
         return Rex::TaskList->run($self->name);
      }

      # this is a method call
      # so run the task

      my $in_transaction = $options{in_transaction};
      
      $self->run_hook(\$server, "before");
      $self->connect($server);

      # execute code
      my $ret = $self->executor->exec;

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
      Rex::TaskList->run($task);
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

1;
