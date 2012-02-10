#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Config;

use strict;
use warnings;

use Rex::Logger;

our ($user, $password, $port,
            $timeout, $max_connect_fails,
            $password_auth, $key_auth, $public_key, $private_key, $parallelism, $log_filename, $log_facility, $sudo_password,
            $path,
            $set_param,
            $environment,
            $SET_HANDLER,
            %SSH_CONFIG_FOR);


sub set_path {
   my $class = shift;
   $path = shift;
}

sub get_path {
   if(!$path) {
      return ("/bin", "/sbin", "/usr/bin", "/usr/sbin", "/usr/local/bin", "/usr/local/sbin", "/usr/pkg/bin", "/usr/pkg/sbin");
   }
   return @{ $path };
}

sub set_user {
   my $class = shift;
   $user = shift;
}

sub set_password {
   my $class = shift;
   $password = shift;
}

sub set_port {
   my $class = shift;
   $port = shift;
}

sub set_sudo_password {
   my $class = shift;
   $sudo_password = shift;
}

sub set_max_connect_fails {
   my $class = shift;
   $max_connect_fails = shift;
}

sub get_max_connect_fails {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{connectionattempts}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{connectionattempts};
   }

   return $max_connect_fails || 3;
}

sub has_user {
   my $class = shift;
   return $user;
}

sub get_user {
   my $class = shift;
   if($user) {
      return $user;
   }

   return $ENV{"USER"};
}

sub get_password {
   my $class = shift;
   return $password;
}

sub get_port {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{port}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{port};
   }

   return $port;
}

sub get_sudo_password {
   my $class = shift;
   return $sudo_password;
}

sub set_timeout {
   my $class = shift;
   $timeout = shift;
}

sub get_timeout {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{connecttimeout}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{connecttimeout};
   }

   return $timeout || 2;
}

sub set_password_auth {
   my $class = shift;
   $password_auth = shift || 1;
}

sub set_key_auth {
   my $class = shift;
   $key_auth = shift || 1;
}

sub get_password_auth {
   return $password_auth;
}

sub get_key_auth {
   return $key_auth;
}

sub set_public_key {
   my $class = shift;
   $public_key = shift;
}

sub has_public_key {
   return $public_key;
}

sub get_public_key {
   if($public_key) {
      return $public_key;
   }

   return _home_dir() . '/.ssh/id_rsa.pub';
}

sub set_private_key {
   my $class = shift;
   $private_key = shift;
}

sub has_private_key {
   return $private_key;
}

sub get_private_key {
   if($private_key) {
      return $private_key;
   }

   return _home_dir() . '/.ssh/id_rsa';
}

sub set_parallelism {
   my $class = shift;
   $parallelism = $_[0];
}

sub get_parallelism {
   my $class = shift;
   return $parallelism || 1;
}

sub set_log_filename {
   my $class = shift;
   $log_filename = shift;
}

sub get_log_filename {
   my $class = shift;
   return $log_filename;
}

sub set_log_facility {
   my $class = shift;
   $log_facility = shift;
}

sub get_log_facility {
   my $class = shift;
   return $log_facility;
}

sub set_environment {
   my ($class, $env) = @_;
   $environment = $env;
}

sub get_environment {
   return $environment || "";
}

sub get_ssh_config_username {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{user}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{user};
   }

   return 0;
}

sub get_ssh_config_hostname {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{hostname}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{hostname};
   }

   return 0;
}

sub get_ssh_config_private_key {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{identityfile}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{identityfile};
   }

   return 0;
}

sub get_ssh_config_public_key {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{identityfile}) {
      return $SSH_CONFIG_FOR{$param->{server}}->{identityfile} . ".pub";
   }

   return 0;
}

sub register_set_handler {
   my ($class, $handler_name, $code) = @_;
   $SET_HANDLER->{$handler_name} = $code;
}

sub set {
   my ($class, $var, $data) = @_;

   if(exists($SET_HANDLER->{$var})) {
      shift; shift;
      return &{ $SET_HANDLER->{$var} }(@_);
   }

   if(ref($data) eq "HASH") {
      for my $key (keys %{$data}) {
         $set_param->{$var}->{$key} = $data->{$key};
      }
   }
   elsif(ref($data) eq "ARRAY") {
      push(@{$set_param->{$var}}, @{$data});
   }
   else {
      $set_param->{$var} = $data;
   }
}

sub unset {
   my ($class, $var) = @_;
   $set_param->{$var} = undef;
   delete $set_param->{$var};
}

sub get {
   my ($class, $var) = @_;
   if(exists $set_param->{$var}) {
      return $set_param->{$var};
   }
}

sub import {

   if(-f _home_dir() . "/.ssh/config") {
      my ($host, $in_host);
      if(open(my $fh, "<", _home_dir() . "/.ssh/config")) {
         while(my $line = <$fh>) {
            chomp $line;
            next if ($line =~ m/^#/);
            next if ($line =~ m/^\s*$/);

            if($line =~ m/^Host ([^\s]+)/) {
               $in_host = 1;
               $host = $1; 
               $SSH_CONFIG_FOR{$host} = {}; 
               next;
            }   
            elsif($in_host) {
               my ($key, $val) = ($line =~ m/^\s*([^\s]+)\s+(.*)$/);
               $SSH_CONFIG_FOR{$host}->{lc($key)} = $val;
            }   
         }
         close($fh);
      }
   }  

}

sub _home_dir {
   if($^O =~ m/^MSWin/) {
      return $ENV{'USERPROFILE'};
   }

   return $ENV{'HOME'};
}

1;
