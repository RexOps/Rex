#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection::SSH;
   
use strict;
use warnings;

use Rex::Interface::Connection::Base;

use base qw(Rex::Interface::Connection::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub connect {
   my ($self, %option) = @_;

   my ($user, $pass, $private_key, $public_key, $server, $port, $timeout);

   $user    = $option{user};
   $pass    = $option{password};
   $server  = $option{server};
   $port    = $option{port};
   $timeout = $option{timeout};

   $public_key  = Rex::Config->get_public_key;
   $private_key = Rex::Config->get_private_key;

   if( ! Rex::Config->has_user && Rex::Config->get_ssh_config_username(server => $server) ) {
      $user = Rex::Config->get_ssh_config_username(server => $server);
   }

   if( ! Rex::Config->has_private_key && Rex::Config->get_ssh_config_private_key(server => $server) ) {
      $private_key = Rex::Config->get_ssh_config_private_key(server => $server);
   }

   if( ! Rex::Config->has_public_key && Rex::Config->get_ssh_config_public_key(server => $server) ) {
      $public_key = Rex::Config->get_ssh_config_public_key(server => $server);
   }

   $self->{ssh} = Net::SSH2->new;

   my $fail_connect = 0;

   CON_SSH:
      $port    ||= Rex::Config->get_port(server => $server) || 22;
      $timeout ||= Rex::Config->get_timeout(server => $server) || 3;

      $server  = Rex::Config->get_ssh_config_hostname(server => $server) || $server;

      if($server =~ m/^(.*?):(\d+)$/) {
         $server = $1;
         $port   = $2;
      }
      Rex::Logger::info("Connecting to $server:$port (" . $user . ")");
      unless($self->{ssh}->connect($server, $port, Timeout => $timeout)) {
         ++$fail_connect;
         sleep 1;
         goto CON_SSH if($fail_connect < Rex::Config->get_max_connect_fails(server => $server)); # try connecting 3 times

         Rex::Logger::info("Can't connect to $server");

         $self->{connected} = 0;

         return;
      }

   Rex::Logger::debug("Current Error-Code: " . $self->{ssh}->error());
   Rex::Logger::info("Connected to $server, trying to authenticate.");

   $self->{connected} = 1;

   if(Rex::Config->get_password_auth) {
      $self->{auth_ret} = $self->{ssh}->auth_password($user, $pass);
   }
   elsif(Rex::Config->get_key_auth) {
      $self->{auth_ret} = $self->{ssh}->auth_publickey($user, 
                              $public_key, 
                              $private_key, 
                              $pass);
   }
   else {
      $self->{auth_ret} = $self->{ssh}->auth(
                             'username' => $user,
                             'password' => $pass,
                             'publickey' => $public_key,
                             'privatekey' => $private_key);
   }

}

sub disconnect {
   my ($self) = @_;
   $self->get_connection_object->disconnect;
}

sub error {
   my ($self) = @_;
   return $self->get_connection_object->error;
}

sub get_connection_object {
   my ($self) = @_;
   return $self->{ssh};
}

sub is_connected {
   my ($self) = @_;
   return $self->{connected};
}

sub is_authenticated {
   my ($self) = @_;
   return $self->{auth_ret};
}

1;
