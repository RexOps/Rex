#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Task;

use strict;
use warnings;

use Rex::Logger;
use Rex::TaskList;
use Rex::Interface::Connection;
use Rex::Interface::Executor;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);


   return $self;
}

sub connection {
   my ($self) = @_;

   # connect if not already connected
   if(! exists $self->{connection}) {
      $self->{connection} = Rex::Interface::Connection->create($self->get_connection_type);
   }

   return $self->{connection};
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
   if(ref($self->{server}) eq "ARRAY") {
      return $self->{server};
   }
   elsif(ref($self->{server}) eq "CODE") {
      return &{ $self->{server} }();
   }
}

sub desc {
   my ($self) = @_;
   return $self->{desc};
}

sub is_remote {
   my ($self) = @_;
   if(scalar(@{ $self->{server} }) > 0) {
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
}

sub user {
   my ($self) = @_;
   return $self->{auth}->{user};
}

sub password {
   my ($self) = @_;
   return $self->{auth}->{password};
}

sub name {
   my ($self) = @_;
   return $self->{name};
}

sub code {
   my ($self) = @_;
   return $self->{func};
}

sub run_hook {
   my ($self, $hook) = @_;
}

sub connect {
   my ($self, $server) = @_;

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

   $self->run_hook("around");

}

sub disconnect {
   my ($self, $server) = @_;

   $self->run_hook("around");
   $self->connection->disconnect;

   # need to get rid of this
   Rex::pop_connection();
}

#####################################
# deprecated functions
# for compatibility
#####################################

sub run {
   my ($class, $task) = @_;

   if(ref($class)) {
      # this is a method call
#      my $self = $class;
#
#      my @all_server = @{ $self->server };
#
#      for my $server (@all_server) {
#
#         $self->run_hook("before");
#         $self->connect($server);
#
#         # execute code
#         my $ret = $self->executor->exec($self);
#
#         $self->disconnect($server);
#         $self->run_hook("after");
#
#      }

   }

   else {
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
