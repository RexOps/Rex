#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Config - Handles the configuration.

=head1 DESCRIPTION

This module holds all configuration parameters for Rex.

With this module you can specify own configuration parameters for your modules.

=head1 EXPORTED METHODS

=over 4

=cut


package Rex::Config;

use strict;
use warnings;

use Rex::Logger;
use YAML;
use Data::Dumper;

our ($user, $password, $port,
            $timeout, $max_connect_fails,
            $password_auth, $key_auth, $public_key, $private_key, $parallelism, $log_filename, $log_facility, $sudo_password,
            $ca_file, $ca_cert, $ca_key,
            $path,
            $set_param,
            $environment,
            $connection_type,
            $distributor,
            $template_function,
            $SET_HANDLER, $HOME_CONFIG, $HOME_CONFIG_YAML,
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

   return getlogin || getpwuid($<) || "Kilroy";
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
   return $sudo_password || $password || "";
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
   $key_auth = 0;
   $password_auth = shift || 1;
}

sub set_key_auth {
   my $class = shift;
   $password_auth = 0;
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

      my $file = $SSH_CONFIG_FOR{$param->{server}}->{identityfile};
      my $home_dir = _home_dir();
      $file =~ s/^~/$home_dir/;
      
      return $file;
   }

   return 0;
}

sub get_ssh_config_public_key {
   my $class = shift;
   my $param = { @_ };

   if(exists $param->{server} && exists $SSH_CONFIG_FOR{$param->{server}}
         && exists $SSH_CONFIG_FOR{$param->{server}}->{identityfile}) {
      my $file = $SSH_CONFIG_FOR{$param->{server}}->{identityfile} . ".pub";
      my $home_dir = _home_dir();
      $file =~ s/^~/$home_dir/;
      return $file;
   }

   return 0;
}

sub get_connection_type {
   my $class = shift;
   return $connection_type || "SSH";
}

sub get_ca {
   my $class = shift;
   return $ca_file || "";
}

sub get_ca_cert {
   my $class = shift;
   return $ca_cert || "";
}

sub get_ca_key {
   my $class = shift;
   return $ca_key || "";
}


sub set_distributor {
   my $class = shift;
   $distributor = shift;
}

sub get_distributor {
   my $class = shift;
   return $distributor || "Base";
}

sub set_template_function {
   my $class = shift;
   ($template_function) = @_;
}

sub get_template_function {
   if(ref($template_function) eq "CODE") {
      return $template_function;
   }

   return sub {
         my ($content, $template_vars) = @_;
         use Rex::Template;
         my $template = Rex::Template->new;
         return $template->parse($content, $template_vars);
   };
}

=item register_set_handler($handler_name, $code)

Register a handler that gets called by I<set>.

 Rex::Config->register_set_handler("foo", sub {
    my ($value) = @_;
    print "The user set foo -> $value\n";
 });

And now you can use this handler in your I<Rexfile> like this:

 set foo => "bar";

=cut
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

=item register_config_handler($topic, $code)

With this function it is possible to register own sections in the users config file ($HOME/.rex/config.yml).

Example:

 Rex::Config->register_config_handler("foo", sub {
   my ($param) = @_;
   print "bar is: " . $param->{bar} . "\n";
 });

And now the user can set this in his configuration file:

 base:
    user: theuser
    password: thepassw0rd
 foo:
    bar: baz

=cut
sub register_config_handler {
   my ($class, $topic, $code) = @_;

   if(! ref($HOME_CONFIG)) { $HOME_CONFIG = {}; }
   $HOME_CONFIG->{$topic} = $code;

   if(ref($HOME_CONFIG_YAML) && exists $HOME_CONFIG_YAML->{$topic}) {
      &$code($HOME_CONFIG_YAML->{$topic});
   }
}

sub import {
   if(-f _home_dir() . "/.ssh/config") {
      my (@host, $in_host);
      if(open(my $fh, "<", _home_dir() . "/.ssh/config")) {
         while(my $line = <$fh>) {
            chomp $line;
            next if ($line =~ m/^#/);
            next if ($line =~ m/^\s*$/);

            if($line =~ m/^Host (.*)$/) {
               my $host_tmp = $1; 
               @host = split(/\s+/, $host_tmp);
               $in_host = 1;
               for my $h (@host) {
                  $SSH_CONFIG_FOR{$h} = {}; 
               }
               next;
            }   
            elsif($in_host) {
               my ($key, $val) = ($line =~ m/^\s*([^\s]+)\s+(.*)$/);
               for my $h (@host) {
                  $SSH_CONFIG_FOR{$h}->{lc($key)} = $val;
               }
            }   
         }
         close($fh);
      }
   }

   if(-f _home_dir() . "/.rex/config.yml") {
      my $yaml = eval { local(@ARGV, $/) = (_home_dir() . "/.rex/config.yml"); <>; };
      eval {
         $HOME_CONFIG_YAML = Load($yaml);
      };

      if($@) {
         print STDERR "Error loading " . _home_dir() . "/.rex/config.yml\n";
         print STDERR "$@\n";
         exit 2;
      }

      for my $key (keys %{ $HOME_CONFIG }) {
         if(exists $HOME_CONFIG_YAML->{$key}) {
            my $code = $HOME_CONFIG->{$key};
            &$code($HOME_CONFIG_YAML->{$key});
         }
      }
   }
}

no strict 'refs';
__PACKAGE__->register_config_handler(base => sub {
   my ($param) = @_;

   for my $key (keys %{ $param }) {

      if($key eq "keyauth") {
         $key_auth = $param->{keyauth};
         next;
      }

      if($key eq "passwordauth") {
         $password_auth = $param->{passwordauth};
         next;
      }

      if($key eq "passauth") {
         $password_auth = $param->{passauth};
         next;
      }

      $$key = $param->{$key};
   }
});

my @set_handler = qw/user password private_key public_key -keyauth -passwordauth -passauth parallelism sudo_password connection ca cert key distributor template_function/;
for my $hndl (@set_handler) {
   __PACKAGE__->register_set_handler($hndl => sub {
      my ($val) = @_;
      if($hndl =~ m/^\-/) {
         $hndl = substr($hndl, 1);
      }
      if($hndl eq "keyauth") { $hndl = "key_auth"; $val = 1; }
      if($hndl eq "passwordauth" || $hndl eq "passauth") { $hndl = "password_auth"; $val = 1; }
      if($hndl eq "connection") { $hndl = "connection_type"; }
      if($hndl eq "ca") { $hndl = "ca_file"; }
      if($hndl eq "cert") { $hndl = "ca_cert"; }
      if($hndl eq "key") { $hndl = "ca_key"; }

      $$hndl = $val; 
   });
}

use strict;

sub _home_dir {
   if($^O =~ m/^MSWin/) {
      return $ENV{'USERPROFILE'};
   }

   return $ENV{'HOME'} || "";
}

=back

=cut

1;
