#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection::OpenSSH;
   
use strict;
use warnings;

use Rex::Interface::Connection::Base;

use Net::OpenSSH;
use base qw(Rex::Interface::Connection::Base);

our $DISABLE_STRICT_HOST_CHECKING = 0;

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

   Rex::Logger::debug("Using Net::OpenSSH for connection");

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

   $self->{__auth_info__} = \%option;

   Rex::Logger::debug("Using user: " . $user);
   Rex::Logger::debug("Using password: " . ($pass?"***********":"<no password>"));

   $self->{server} = $server;


   my $fail_connect = 0;

   $port    ||= Rex::Config->get_port(server => $server) || 22;
   $timeout ||= Rex::Config->get_timeout(server => $server) || 3;

   $server  = Rex::Config->get_ssh_config_hostname(server => $server) || $server;

   if($server =~ m/^(.*?):(\d+)$/) {
      $server = $1;
      $port   = $2;
   }
   Rex::Logger::info("Connecting to $server:$port (" . $user . ")");

   if($auth_type && $auth_type eq "pass") {
      Rex::Logger::info("OpenSSH: pass_auth: $server:$port - $user - $pass");
      $self->{ssh} = Net::OpenSSH->new($server, user => $user, password => $pass, port => $port, master_opts => [-o => ($DISABLE_STRICT_HOST_CHECKING ? "StrictHostKeyChecking" : "")]);
   }
   elsif($auth_type && $auth_type eq "key") {
      my %a = (
         user => $user,
         key_path => $private_key,
      );
      if($pass) {
         $a{passphrase} = $pass;
      }
      $self->{ssh} = Net::OpenSSH->new($server, %a);
   }
   elsif($auth_type && $auth_type eq "krb5") {
      $self->{ssh} = Net::OpenSSH->new($server, user => $user);
   }
   else {
      my %a = (
         user => $user,
         key_path => $private_key,
      );
      if($pass) {
         $a{passphrase} = $pass;
         $a{password}   = $pass;
      }

      $self->{ssh} = Net::OpenSSH->new($server, %a);
   }

   if(! $self->{ssh}) {
      Rex::Logger::info("Can't connect to $server", "warn");
      $self->{connected} = 0;

      return;
   }

   if($self->{ssh}->error) {
      Rex::Logger::info("Can't connect to $server", "warn");
      $self->{connected} = 0;
      return;
   }

   Rex::Logger::debug("Current Error-Code: " . $self->{ssh}->error());
   Rex::Logger::info("Connected and authenticated to $server.");

   $self->{connected} = 1;
   $self->{auth_ret}  = 1;

   $self->{sftp} = $self->{ssh}->sftp;
}

sub reconnect {
   my ($self) = @_;
   Rex::Logger::debug("Reconnecting SSH");

   $self->connect(%{ $self->{__auth_info__} });
}

sub disconnect {
   my ($self) = @_;
   undef $self->{ssh};
   return 1;
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

   my $type = "OpenSSH";

   if($self->{is_sudo} && $self->{is_sudo} == 1) {
      return "Sudo";
   }

   if(Rex::is_ssh() && ! Rex::is_sudo()) {
      $type = "OpenSSH";
   }
   elsif(Rex::is_sudo()) {
      $type = "Sudo";
   }
 
   return $type;
}

1;
