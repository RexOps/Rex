#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Config - Handles the configuration.

=head1 DESCRIPTION

This module holds all configuration parameters for Rex.

With this module you can specify own configuration parameters for your modules.

=head1 EXPORTED METHODS

=cut

package Rex::Config;

use strict;
use warnings;

# VERSION

use Rex::Helper::File::Spec;
use Rex::Logger;
use YAML;
use Data::Dumper;
use Rex::Require;

our (
  $user,                     $password,
  $port,                     $timeout,
  $max_connect_fails,        $password_auth,
  $key_auth,                 $krb5_auth,
  $public_key,               $private_key,
  $parallelism,              $log_filename,
  $log_facility,             $sudo_password,
  $ca_file,                  $ca_cert,
  $ca_key,                   $path,
  $no_path_cleanup,          $set_param,
  $environment,              $connection_type,
  $distributor,              $template_function,
  $SET_HANDLER,              $HOME_CONFIG,
  $HOME_CONFIG_YAML,         %SSH_CONFIG_FOR,
  $sudo_without_locales,     $sudo_without_sh,
  $no_tty,                   $source_global_profile,
  $source_profile,           %executor_for,
  $allow_empty_groups,       $use_server_auth,
  $tmp_dir,                  %openssh_opt,
  $use_cache,                $cache_type,
  $use_sleep_hack,           $report_type,
  $do_reporting,             $say_format,
  $exec_autodie,             $verbose_run,
  $disable_taskname_warning, $proxy_command,
  $task_call_by_method,      $fallback_auth,
  $register_cmdb_template,   $check_service_exists,
  $set_no_append,            $use_net_openssh_if_present,
  $use_template_ng,          $use_rex_kvm_agent,
  $autodie,                  $task_chaining_cmdline_args,

);

# some defaults
%executor_for = (
  perl   => "perl",
  python => "python",
  ruby   => "ruby",
  bash   => "bash",
);

sub set_autodie {
  my $class = shift;
  $autodie = shift;
}

sub get_autodie {
  return $autodie;
}

sub set_use_net_openssh_if_present {
  my $class = shift;
  $use_net_openssh_if_present = shift;
}

sub get_use_net_openssh_if_present {
  return $use_net_openssh_if_present;
}

sub set_use_rex_kvm_agent {
  my $class = shift;
  $use_rex_kvm_agent = shift;
}

sub get_use_rex_kvm_agent {
  return $use_rex_kvm_agent;
}

sub set_use_template_ng {
  my $class = shift;
  $use_template_ng = shift;
}

sub get_use_template_ng {
  return $use_template_ng;
}

sub set_set_no_append {
  my $class = shift;
  $set_no_append = shift;
}

sub get_set_no_append {
  return $set_no_append;
}

sub set_check_service_exists {
  my $class = shift;
  $check_service_exists = shift;
}

sub get_check_service_exists {
  return $check_service_exists;
}

sub set_register_cmdb_template {
  my $class = shift;
  $register_cmdb_template = shift;
}

sub get_register_cmdb_template {
  return $register_cmdb_template;
}

sub set_fallback_auth {
  my $class = shift;
  $fallback_auth = [@_];
}

sub get_fallback_auth {
  return $fallback_auth;
}

sub set_task_call_by_method {
  my $class = shift;
  $task_call_by_method = shift;
}

sub get_task_call_by_method {
  return $task_call_by_method;
}

sub set_disable_taskname_warning {
  my $class = shift;
  $disable_taskname_warning = shift;
}

sub get_disable_taskname_warning {
  return $disable_taskname_warning;
}

sub set_task_chaining_cmdline_args {
  my $class = shift;
  $task_chaining_cmdline_args = shift;
}

sub get_task_chaining_cmdline_args {
  return $task_chaining_cmdline_args;
}

sub set_verbose_run {
  my $class = shift;
  $verbose_run = shift;
}

sub get_verbose_run {
  return $verbose_run;
}

sub set_exec_autodie {
  my $class = shift;
  $exec_autodie = shift;
}

sub get_exec_autodie {
  return $exec_autodie;
}

sub set_no_path_cleanup {
  my $class = shift;
  $no_path_cleanup = shift;
}

sub get_no_path_cleanup {
  return $no_path_cleanup;
}

sub set_source_profile {
  my $class = shift;
  $source_profile = shift;
}

sub get_source_profile {
  return $source_profile;
}

sub set_say_format {
  my $class = shift;
  $say_format = shift;
}

sub get_say_format {
  return $say_format;
}

sub set_do_reporting {
  my $class = shift;
  $do_reporting = shift;
}

sub get_do_reporting {
  return $do_reporting;
}

sub set_report_type {
  my $class = shift;
  $report_type = shift;
}

sub get_report_type {
  if ( exists $ENV{REX_REPORT_TYPE} ) {
    return $ENV{REX_REPORT_TYPE};
  }

  return $report_type;
}

sub set_sleep_hack {
  my $class = shift;
  $use_sleep_hack = shift;
}

sub get_sleep_hack {
  return $use_sleep_hack;
}

sub set_cache_type {
  my $class = shift;
  $cache_type = shift;
}

sub get_cache_type {
  if ( exists $ENV{REX_CACHE_TYPE} ) {
    return $ENV{REX_CACHE_TYPE};
  }

  return $cache_type || "Base";
}

sub set_use_cache {
  my $class = shift;
  $use_cache = shift;
}

sub get_use_cache {
  return $use_cache;
}

sub get_sudo_without_locales {
  return $sudo_without_locales;
}

sub get_sudo_without_sh {
  return $sudo_without_sh;
}

sub set_openssh_opt {
  my ( $class, %opt ) = @_;

  for my $key ( keys %opt ) {
    if ( !defined $opt{$key} ) {
      $openssh_opt{$key} = undef;
      delete $openssh_opt{$key};
      next;
    }

    $openssh_opt{$key} = $opt{$key};
  }
}

sub get_openssh_opt {
  return %openssh_opt;
}

sub set_sudo_without_locales {
  my $class = shift;
  $sudo_without_locales = shift;
}

sub set_sudo_without_sh {
  my $class = shift;
  $sudo_without_sh = shift;
}

sub set_executor_for {
  my $class = shift;
  my $for   = shift;
  my $e     = shift;

  $executor_for{$for} = $e;
}

sub get_executor_for {
  my $class = shift;
  my $e     = shift;

  return $executor_for{$e};
}

sub set_tmp_dir {
  my ( $class, $dir ) = @_;
  if ( $class eq "Rex::Config" ) {
    $tmp_dir = $dir;
  }
  else {
    $tmp_dir = $class;
  }
}

sub get_tmp_dir {
  my $cache = Rex::get_cache();
  if ( my $cached_tmp = $cache->get("tmpdir") ) {
    return $cached_tmp;
  }

  if ( !$tmp_dir ) {
    if ( my $ssh = Rex::is_ssh() ) {
      my $exec;
      if ( Rex::is_sudo() ) {
        if ( ref $ssh eq "Net::OpenSSH" ) {
          $exec = Rex::Interface::Exec->create("OpenSSH");
        }
        else {
          $exec = Rex::Interface::Exec->create("SSH");
        }
      }
      else {
        $exec = Rex::Interface::Exec->create;
      }
      my ($out) =
        $exec->exec("perl -MFile::Spec -le 'print File::Spec->tmpdir'");

      if ( $? == 0 && $out ) {
        $out =~ s/[\r\n]//gms;

        $cache->set( "tmpdir", $out );
        return $out;
      }
      $cache->set( "tmpdir", "/tmp" );
      return "/tmp";
    }
    else {
      $cache->set( "tmpdir", Rex::Helper::File::Spec->tmpdir );
      return Rex::Helper::File::Spec->tmpdir;
    }
  }
  return $tmp_dir;
}

sub set_path {
  my $class = shift;
  $path = shift;
}

sub get_path {
  if ( !$path ) {
    return (
      "/bin",         "/sbin",          "/usr/bin",
      "/usr/sbin",    "/usr/local/bin", "/usr/local/sbin",
      "/usr/pkg/bin", "/usr/pkg/sbin"
    );
  }
  return @{$path};
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

sub set_source_global_profile {
  my $class = shift;
  $source_global_profile = shift;
}

sub get_source_global_profile {
  return $source_global_profile;
}

sub set_max_connect_fails {
  my $class = shift;
  $max_connect_fails = shift;
}

sub get_max_connect_fails {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{connectionattempts} )
  {
    return $SSH_CONFIG_FOR{ $param->{server} }->{connectionattempts};
  }

  return $max_connect_fails || 3;
}

sub has_user {
  my $class = shift;
  return $user;
}

sub get_user {
  my $class = shift;

  if ( exists $ENV{REX_USER} ) {
    return $ENV{REX_USER};
  }

  if ($user) {
    return $user;
  }

  return getlogin || getpwuid($<) || "Kilroy";
}

sub get_password {
  my $class = shift;

  if ( exists $ENV{REX_PASSWORD} ) {
    return $ENV{REX_PASSWORD};
  }

  return $password;
}

sub get_port {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{port} )
  {
    return $SSH_CONFIG_FOR{ $param->{server} }->{port};
  }

  return $port;
}

sub set_proxy_command {
  my $class = shift;
  $proxy_command = shift;
}

sub get_proxy_command {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{proxycommand} )
  {
    return $SSH_CONFIG_FOR{ $param->{server} }->{proxycommand};
  }

  return $proxy_command;
}

sub get_sudo_password {
  my $class = shift;

  if ( exists $ENV{REX_SUDO_PASSWORD} ) {
    return $ENV{REX_SUDO_PASSWORD};
  }

  if ($sudo_password) {
    return $sudo_password;
  }
  elsif ( !defined $sudo_password ) {
    return "";
  }
  else {
    return $password;
  }

  return "";
}

sub set_timeout {
  my $class = shift;
  $timeout = shift;
}

sub get_timeout {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{connecttimeout} )
  {
    return $SSH_CONFIG_FOR{ $param->{server} }->{connecttimeout};
  }

  return $timeout || 2;
}

sub set_password_auth {
  my $class = shift;
  $key_auth      = 0;
  $krb5_auth     = 0;
  $password_auth = shift || 1;
}

sub set_key_auth {
  my $class = shift;
  $password_auth = 0;
  $krb5_auth     = 0;
  $key_auth      = shift || 1;
}

sub set_krb5_auth {
  my $class = shift;
  $password_auth = 0;
  $key_auth      = 0;
  $krb5_auth     = shift || 1;
}

sub get_password_auth {
  if ( exists $ENV{REX_AUTH_TYPE} && $ENV{REX_AUTH_TYPE} eq "pass" ) {
    return 1;
  }
  return $password_auth;
}

sub get_key_auth {
  if ( exists $ENV{REX_AUTH_TYPE} && $ENV{REX_AUTH_TYPE} eq "key" ) {
    return 1;
  }
  return $key_auth;
}

sub get_krb5_auth {
  if ( exists $ENV{REX_AUTH_TYPE} && $ENV{REX_AUTH_TYPE} eq "krb5" ) {
    return 1;
  }
  return $krb5_auth;
}

sub set_public_key {
  my $class = shift;
  $public_key = shift;
}

sub has_public_key {
  return get_public_key();
}

sub get_public_key {
  if ( exists $ENV{REX_PUBLIC_KEY} ) { return $ENV{REX_PUBLIC_KEY}; }
  if ($public_key) {
    return $public_key;
  }

  return;
}

sub set_private_key {
  my $class = shift;
  $private_key = shift;
}

sub has_private_key {
  return get_private_key();
}

sub get_private_key {
  if ( exists $ENV{REX_PRIVATE_KEY} ) { return $ENV{REX_PRIVATE_KEY}; }
  if ($private_key) {
    return $private_key;
  }

  return;
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
  return $log_facility || "local0";
}

sub set_environment {
  my ( $class, $env ) = @_;
  $environment = $env;
}

sub get_environment {
  return $environment || "";
}

sub get_ssh_config_username {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{user} )
  {
    return $SSH_CONFIG_FOR{ $param->{server} }->{user};
  }

  return 0;
}

sub get_ssh_config_hostname {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{hostname} )
  {
    return $SSH_CONFIG_FOR{ $param->{server} }->{hostname};
  }

  return 0;
}

sub get_ssh_config_private_key {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{identityfile} )
  {

    my $file     = $SSH_CONFIG_FOR{ $param->{server} }->{identityfile};
    my $home_dir = _home_dir();
    $file =~ s/^~/$home_dir/;

    return $file;
  }

  return 0;
}

sub get_ssh_config_public_key {
  my $class = shift;
  my $param = {@_};

  if ( exists $param->{server}
    && exists $SSH_CONFIG_FOR{ $param->{server} }
    && exists $SSH_CONFIG_FOR{ $param->{server} }->{identityfile} )
  {
    my $file     = $SSH_CONFIG_FOR{ $param->{server} }->{identityfile} . ".pub";
    my $home_dir = _home_dir();
    $file =~ s/^~/$home_dir/;
    return $file;
  }

  return 0;
}

sub get_connection_type {
  my $class = shift;

  if ( $^O !~ m/^MSWin/ && !$connection_type && $use_net_openssh_if_present ) {
    my $has_net_openssh = 0;
    eval {
      Net::OpenSSH->require;
      Net::SFTP::Foreign->require;
      $has_net_openssh = 1;
      1;
    };

    if ($has_net_openssh) {
      Rex::Logger::debug(
        "Found Net::OpenSSH and Net::SFTP::Foreign - using it as default");
      $connection_type = "OpenSSH";
      return "OpenSSH";
    }
  }

  if ( !$connection_type ) {
    my $has_net_ssh2 = 0;
    eval {
      Net::SSH2->require;
      $has_net_ssh2 = 1;
      1;
    };

    if ($has_net_ssh2) {
      $connection_type = "SSH";
      return "SSH";
    }
  }

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
  if ( ref($template_function) eq "CODE" ) {
    return sub {
      my ( $content, $template_vars ) = @_;
      $template_vars =
        { %{ Rex::Commands::task()->get_all_parameters }, %{$template_vars} }
        if ( Rex::Commands::task() );
      return $template_function->( $content, $template_vars );
    };
  }

  if ( Rex::Template::NG->is_loadable && get_use_template_ng() ) {

    # new template engine
    return sub {
      my ( $content, $template_vars ) = @_;
      $template_vars =
        { %{ Rex::Commands::task()->get_all_parameters }, %{$template_vars} }
        if ( Rex::Commands::task() );
      Rex::Template::NG->require;
      my $t = Rex::Template::NG->new;
      return $t->parse( $content, %{$template_vars} );
    };
  }

  return sub {
    my ( $content, $template_vars ) = @_;
    $template_vars =
      { %{ Rex::Commands::task()->get_all_parameters }, %{$template_vars} }
      if ( Rex::Commands::task() );
    use Rex::Template;
    my $template = Rex::Template->new;
    return $template->parse( $content, $template_vars );
  };
}

sub set_no_tty {
  shift;
  $no_tty = shift;
}

sub get_no_tty {
  return $no_tty;
}

=head2 register_set_handler($handler_name, $code)

Register a handler that gets called by I<set>.

 Rex::Config->register_set_handler("foo", sub {
   my ($value) = @_;
   print "The user set foo -> $value\n";
 });

And now you can use this handler in your I<Rexfile> like this:

 set foo => "bar";

=cut

sub register_set_handler {
  my ( $class, $handler_name, $code ) = @_;
  $SET_HANDLER->{$handler_name} = $code;
}

sub set {
  my ( $class, $var, $data ) = @_;

  if ( exists( $SET_HANDLER->{$var} ) ) {
    shift;
    shift;
    return &{ $SET_HANDLER->{$var} }(@_);
  }

  if ($set_no_append) {
    $set_param->{$var} = $data;
  }
  else {
    if ( ref($data) eq "HASH" ) {
      if ( !ref( $set_param->{$var} ) ) {
        $set_param->{$var} = {};
      }
      for my $key ( keys %{$data} ) {
        $set_param->{$var}->{$key} = $data->{$key};
      }
    }
    elsif ( ref($data) eq "ARRAY" ) {
      push( @{ $set_param->{$var} }, @{$data} );
    }
    else {
      $set_param->{$var} = $data;
    }
  }
}

sub unset {
  my ( $class, $var ) = @_;
  $set_param->{$var} = undef;
  delete $set_param->{$var};
}

sub get {
  my ( $class, $var ) = @_;
  $var or return;
  if ( exists $set_param->{$var} ) {
    return $set_param->{$var};
  }
}

sub get_all {
  my ($class) = @_;
  return $set_param;
}

=head2 register_config_handler($topic, $code)

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
  my ( $class, $topic, $code ) = @_;

  if ( !ref($HOME_CONFIG) ) { $HOME_CONFIG = {}; }
  $HOME_CONFIG->{$topic} = $code;

  if ( ref($HOME_CONFIG_YAML) && exists $HOME_CONFIG_YAML->{$topic} ) {
    &$code( $HOME_CONFIG_YAML->{$topic} );
  }
}

sub read_config_file {
  my ($config_file) = @_;
  $config_file ||= _home_dir() . "/.rex/config.yml";

  if ( -f $config_file ) {
    my $yaml = eval { local ( @ARGV, $/ ) = ($config_file); <>; };
    eval { $HOME_CONFIG_YAML = Load($yaml); };

    if ($@) {
      print STDERR "Error loading $config_file\n";
      print STDERR "$@\n";
      exit 2;
    }

    for my $key ( keys %{$HOME_CONFIG} ) {
      if ( exists $HOME_CONFIG_YAML->{$key} ) {
        my $code = $HOME_CONFIG->{$key};
        &$code( $HOME_CONFIG_YAML->{$key} );
      }
    }
  }
}

sub read_ssh_config_file {
  my ($config_file) = @_;
  $config_file ||= _home_dir() . '/.ssh/config';

  if ( -f $config_file ) {
    my @lines = eval { local (@ARGV) = ($config_file); <>; };
    %SSH_CONFIG_FOR = _parse_ssh_config(@lines);
  }
}

sub _parse_ssh_config {
  my (@lines) = @_;

  my %ret = ();

  my ( @host, $in_host );
  for my $line (@lines) {
    chomp $line;
    next if ( $line =~ m/^\s*#/ );
    next if ( $line =~ m/^\s*$/ );

    if ( $line =~ m/^Host(?:\s*=\s*|\s+)(.*)$/i ) {
      my $host_tmp = $1;
      @host = split( /\s+/, $host_tmp );
      $in_host = 1;
      for my $h (@host) {
        $ret{$h} = {};
      }
      next;
    }
    elsif ($in_host) {

      #my ($key, $val) = ($line =~ m/^\s*([^\s]+)\s+=?\s*(.*)$/);
      $line =~ s/^\s*//g;
      my ( $key, $val_tmp ) = split( /[\s=]/, $line, 2 );
      $val_tmp =~ s/^[\s=]+//g;
      my $val = $val_tmp;

      $val =~ s/^\s+//;
      $val =~ s/\s+$//;
      for my $h (@host) {
        $ret{$h}->{ lc($key) } = $val;
      }
    }
  }

  return %ret;
}

sub set_allow_empty_groups {
  my ( $class, $set ) = @_;
  if ($set) {
    $allow_empty_groups = 1;
  }
  else {
    $allow_empty_groups = 0;
  }
}

sub get_allow_empty_groups {
  if ($allow_empty_groups) {
    return 1;
  }

  return 0;
}

sub set_use_server_auth {
  my ( $class, $set ) = @_;
  if ($set) {
    $use_server_auth = 1;
  }
  else {
    $use_server_auth = 0;
  }
}

sub get_use_server_auth {
  if ($use_server_auth) {
    return 1;
  }

  return 0;
}

sub import {
  read_ssh_config_file();
  read_config_file();
}

no strict 'refs';
__PACKAGE__->register_config_handler(
  base => sub {
    my ($param) = @_;

    for my $key ( keys %{$param} ) {

      if ( $key eq "keyauth" ) {
        $key_auth = $param->{keyauth};
        next;
      }

      if ( $key eq "passwordauth" ) {
        $password_auth = $param->{passwordauth};
        next;
      }

      if ( $key eq "passauth" ) {
        $password_auth = $param->{passauth};
        next;
      }

      $$key = $param->{$key};
    }
  }
);

my @set_handler =
  qw/user password private_key public_key -keyauth -passwordauth -passauth
  parallelism sudo_password connection ca cert key distributor
  template_function port/;
for my $hndl (@set_handler) {
  __PACKAGE__->register_set_handler(
    $hndl => sub {
      my ($val) = @_;
      if ( $hndl =~ m/^\-/ ) {
        $hndl = substr( $hndl, 1 );
      }
      if ( $hndl eq "keyauth" ) { $hndl = "key_auth"; $val = 1; }
      if ( $hndl eq "passwordauth" || $hndl eq "passauth" ) {
        $hndl = "password_auth";
        $val  = 1;
      }
      if ( $hndl eq "connection" ) { $hndl = "connection_type"; }
      if ( $hndl eq "ca" )         { $hndl = "ca_file"; }
      if ( $hndl eq "cert" )       { $hndl = "ca_cert"; }
      if ( $hndl eq "key" )        { $hndl = "ca_key"; }

      $$hndl = $val;
    }
  );
}

use strict;

sub _home_dir {
  if ( $^O =~ m/^MSWin/ ) {
    return $ENV{'USERPROFILE'};
  }

  return $ENV{'HOME'} || "";
}

1;
