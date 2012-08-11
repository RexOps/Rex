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

   my ($user, $pass, $private_key, $public_key, $server, $port, $timeout, $auth_type, $is_sudo);

   $user    = $option{user};
   $pass    = $option{password};
   $server  = $option{server};
   $port    = $option{port};
   $timeout = $option{timeout};
   $public_key = $option{public_key};
   $private_key = $option{private_key};
   $auth_type   = $option{auth_type};
   $is_sudo     = $option{sudo};

   $self->{is_sudo} = $is_sudo;

   Rex::Logger::debug("Using user: " . $user);
   Rex::Logger::debug("Using password: " . ($pass?"***********":"<no password>"));

   $self->{server} = $server;

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

         Rex::Logger::info("Can't connect to $server", "warn");

         $self->{connected} = 0;

         return;
      }

   Rex::Logger::debug("Current Error-Code: " . $self->{ssh}->error());
   Rex::Logger::info("Connected to $server, trying to authenticate.");

   $self->{connected} = 1;

   if($auth_type eq "pass") {
      Rex::Logger::debug("Using password authentication.");
      $self->{auth_ret} = $self->{ssh}->auth_password($user, $pass);
   }
   elsif($auth_type eq "key") {
      Rex::Logger::debug("Using key authentication.");
      $self->{auth_ret} = $self->{ssh}->auth_publickey($user,
                              $public_key,
                              $private_key,
                              $pass);
   }
   else {
      Rex::Logger::debug("Trying to guess the authentication method.");
      $self->{auth_ret} = $self->{ssh}->auth(
                             'username' => $user,
                             'password' => $pass,
                             'publickey' => $public_key,
                             'privatekey' => $private_key);
   }

   $self->{sftp} = $self->{ssh}->sftp;
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

sub get_fs_connection_object {
   my ($self) = @_;
   return $self->{sftp};
}

sub is_connected {
   my ($self) = @_;
   return $self->{connected};
}

sub is_authenticated {
   my ($self) = @_;
   return $self->{auth_ret};
}

sub get_connection_type {
   my ($self) = @_;

   my $type = "SSH";

   if($self->{is_sudo} && $self->{is_sudo} == 1) {
      return "Sudo";
   }

   if(Rex::is_ssh() && ! Rex::is_sudo()) {
      $type = "SSH";
   }
   elsif(Rex::is_sudo()) {
      $type = "Sudo";
   }
 
   return $type;
}

1;
