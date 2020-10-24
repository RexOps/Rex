#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Config - Handles Rex configuration

=head1 SYNOPSIS

 use Rex::Config;

 # set a config option
 Rex::Config->set_exec_autodie(TRUE);

 # get value of a config option
 my $user = Rex::Config->get_user();

=head1 DESCRIPTION

This module holds all configuration options for Rex, and also allows you to specify your own ones for your modules.

Please take a look at L<Rex::Commands> first, which provides convenience wrappers for many of these options.

While it's possible to use the methods below to set a configuration option directly, their main intended purpose is to be used as internal plumbing, and to provide an escape hatch in case there are no better alternatives.

=head1 EXPORTED METHODS

=cut

package Rex::Config;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::File::Spec;
use Rex::Logger;
use YAML;
use Data::Dumper;
use Rex::Require;
use Symbol;

our (
  $user,                        $password,
  $port,                        $timeout,
  $max_connect_fails,           $password_auth,
  $key_auth,                    $krb5_auth,
  $public_key,                  $private_key,
  $parallelism,                 $log_filename,
  $log_facility,                $sudo_password,
  $ca_file,                     $ca_cert,
  $ca_key,                      $path,
  $no_path_cleanup,             $set_param,
  $environment,                 $connection_type,
  $distributor,                 $template_function,
  $SET_HANDLER,                 $HOME_CONFIG,
  $HOME_CONFIG_YAML,            %SSH_CONFIG_FOR,
  $sudo_without_locales,        $sudo_without_sh,
  $no_tty,                      $source_global_profile,
  $source_profile,              %executor_for,
  $allow_empty_groups,          $use_server_auth,
  $tmp_dir,                     %openssh_opt,
  $use_cache,                   $cache_type,
  $use_sleep_hack,              $report_type,
  $do_reporting,                $say_format,
  $exec_autodie,                $verbose_run,
  $disable_taskname_warning,    $proxy_command,
  $task_call_by_method,         $fallback_auth,
  $register_cmdb_template,      $check_service_exists,
  $set_no_append,               $use_net_openssh_if_present,
  $use_template_ng,             $use_rex_kvm_agent,
  $autodie,                     $task_chaining_cmdline_args,
  $waitpid_blocking_sleep_time, $write_utf8_files,
  $default_auth,
);

# some defaults
%executor_for = (
  perl   => "perl",
  python => "python",
  ruby   => "ruby",
  bash   => "bash",
);

=head2 set_autodie

=head2 get_autodie

Sets and gets the value of the C<$autodie> configuration variable.

This controls whether Rex should C<die()> if there's an error while executing L<file system commands that are supposed to change the contents|Rex::Commands::Fs#Changing-content>.

Default is C<undef>.

=cut

sub set_autodie {
  my $class = shift;
  $autodie = shift;
}

sub get_autodie {
  return $autodie;
}

=head2 set_use_net_openssh_if_present

=head2 get_use_net_openssh_if_present

Sets and gets the value of the C<$use_net_openssh_if_present> configuration variable.

This controls whether Rex should use L<Net::OpenSSH> for connections if that is available. 

Default is C<undef>.

=cut

sub set_use_net_openssh_if_present {
  my $class = shift;
  $use_net_openssh_if_present = shift;
}

sub get_use_net_openssh_if_present {
  return $use_net_openssh_if_present;
}

=head2 set_use_rex_kvm_agent

=head2 get_use_rex_kvm_agent

Sets and gets the value of the C<$use_rex_kvm_agent> configuration variable.

This controls whether Rex should setup and use a serial device for the experimental L<Rex KVM agent|https://github.com/RexOps/rex-kvm-agent> for managed VMs.

Default is C<undef>.

=cut

sub set_use_rex_kvm_agent {
  my $class = shift;
  $use_rex_kvm_agent = shift;
}

sub get_use_rex_kvm_agent {
  return $use_rex_kvm_agent;
}

=head2 set_use_template_ng

=head2 get_use_template_ng

Sets and gets the value of the C<$use_template_ng> configuration variable.

This controls whether Rex should use L<Rex::Template::NG> to render templates.

Default is C<undef>.

=cut

sub set_use_template_ng {
  my $class = shift;
  $use_template_ng = shift;
}

sub get_use_template_ng {
  return $use_template_ng;
}

=head2 set_set_no_append

=head2 get_set_no_append

Sets and gets the value of the C<$set_no_append> configuration variable.

This controls whether Rex should overwrite or append values of configuration options when using the L<set|Rex::Commands#set> command.

Default is C<undef>.

=cut

sub set_set_no_append {
  my $class = shift;
  $set_no_append = shift;
}

sub get_set_no_append {
  return $set_no_append;
}

=head2 set_check_service_exists

=head2 get_check_service_exists

Sets and gets the value of the C<$check_service_exists> configuration variable.

This controls whether Rex should C<die()> early if it is asked to manage a service that doesn't exist.

Default is C<undef>.

=cut

sub set_check_service_exists {
  my $class = shift;
  $check_service_exists = shift;
}

sub get_check_service_exists {
  return $check_service_exists;
}

=head2 set_register_cmdb_template

=head2 get_register_cmdb_template

Sets and gets the value of the C<$register_cmdb_template> configuration variable.

This controls whether Rex should make L<CMDB|Rex::CMDB> data available to be used in templates as variables.

Default is C<undef>.

=cut

sub set_register_cmdb_template {
  my $class = shift;
  $register_cmdb_template = shift;
}

sub get_register_cmdb_template {
  return $register_cmdb_template;
}

=head2 set_fallback_auth

=head2 get_fallback_auth

Sets and gets the value of the C<$fallback_auth> configuration variable.

This can be used to define an array of hash references, each of them containing L<authentication details|Rex::Commands#auth> to be tried during connection attempts when the directly specified ones fail.

Default is C<undef>.

=cut

sub set_fallback_auth {
  my $class = shift;
  $fallback_auth = [@_];
}

sub get_fallback_auth {
  return $fallback_auth;
}

=head2 set_task_call_by_method

=head2 get_task_call_by_method

Sets and gets the value of the C<$task_call_by_method> configuration variable.

This controls whether calling tasks as a method is allowed or not.

Default is C<undef>.

=cut

sub set_task_call_by_method {
  my $class = shift;
  $task_call_by_method = shift;
}

sub get_task_call_by_method {
  return $task_call_by_method;
}

=head2 set_disable_taskname_warning

=head2 get_disable_taskname_warning

Sets and gets the value of the C<$disable_taskname_warning> configuration variable.

This controls whether Rex should show or suppress the warning message about task names that can not be used as Perl identifiers.

Default is C<undef>.

=cut

sub set_disable_taskname_warning {
  my $class = shift;
  $disable_taskname_warning = shift;
}

sub get_disable_taskname_warning {
  return $disable_taskname_warning;
}

=head2 set_task_chaining_cmdline_args

=head2 get_task_chaining_cmdline_args

Sets and gets the value of the C<$task_chaining_cmdline_args> configuration variable.

This controls whether Rex should parse task arguments on the command line per task, or should pass all arguments to all tasks.

Default is C<undef>.

=cut

sub set_task_chaining_cmdline_args {
  my $class = shift;
  $task_chaining_cmdline_args = shift;
}

sub get_task_chaining_cmdline_args {
  return $task_chaining_cmdline_args;
}

=head2 set_verbose_run

=head2 get_verbose_run

Sets and gets the value of the C<$verbose_run> configuration variable.

This controls whether Rex should show verbose output about executed L<run|Rex::Commands::Run#run> commands. This means an error message if the command is not found, a warning message if the exit code indicates an error, and an informational message upon success.

Default is C<undef>.

=cut

sub set_verbose_run {
  my $class = shift;
  $verbose_run = shift;
}

sub get_verbose_run {
  return $verbose_run;
}

=head2 set_exec_autodie

=head2 get_exec_autodie

Sets and gets the value of the C<$exec_autodie> configuration variable.

This controls whether Rex should C<die()> or not when the exit code of executed L<run|Rex::Commands::Run#run> command indicate an error.

Default is C<undef>.

=cut

sub set_exec_autodie {
  my $class = shift;
  $exec_autodie = shift;
}

sub get_exec_autodie {
  return $exec_autodie;
}

=head2 set_no_path_cleanup

=head2 get_no_path_cleanup

Sets and gets the value of the C<$no_path_cleanup> configuration variable.

This controls whether Rex should clean up the C<$PATH> before executing a L<run|Rex::Commands::Run#run> command.

Default is C<undef>.

=cut

sub set_no_path_cleanup {
  my $class = shift;
  $no_path_cleanup = shift;
}

sub get_no_path_cleanup {
  return $no_path_cleanup;
}

=head2 set_source_profile

=head2 get_source_profile

Sets and gets the value of the C<$source_profile> configuration variable.

This controls whether Rex should source shell-specific profile files before executing commands.

Default is C<undef>.

=cut

sub set_source_profile {
  my $class = shift;
  $source_profile = shift;
}

sub get_source_profile {
  return $source_profile;
}

=head2 set_say_format

=head2 get_say_format

Sets and gets the value of the C<$say_format> configuration variable.

This controls the output format of the built-in C<say> command (see also L<sayformat|Rex::Commands#sayformat>).

Default is C<undef>.

=cut

sub set_say_format {
  my $class = shift;
  $say_format = shift;
}

sub get_say_format {
  return $say_format;
}

=head2 set_do_reporting

=head2 get_do_reporting

Sets and gets the value of the C<$do_reporting> configuration variable.

This controls whether Rex should do reporting on executed resources where it is supported. This only affects the data structures returned internally.

Default is C<undef>.

=cut

sub set_do_reporting {
  my $class = shift;
  $do_reporting = shift;
}

sub get_do_reporting {
  return $do_reporting;
}

=head2 set_report_type

=head2 get_report_type

Sets and gets the value of the C<$report_type> configuration variable, which can also be controlled via the C<REX_REPORT_TYPE> environment variable.

This selects the reporting type (format) Rex should use, e.g. C<'YAML'>.

Default is C<undef>.

=cut

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

=head2 set_sleep_hack

=head2 get_sleep_hack

Sets and gets the value of the C<$sleep_hack> configuration variable.

This controls whether Rex should use or not an extra 10 ns long sleep after executed commands.

This might help working around an issue when Rex runs inside a KVM virtualized host and L<Net::SSH2>/L<libssh2|https://www.libssh2.org> is used to connect to another VM on the same hardware.

Default is C<undef>.

=cut

sub set_sleep_hack {
  my $class = shift;
  $use_sleep_hack = shift;
}

sub get_sleep_hack {
  return $use_sleep_hack;
}

=head2 set_cache_type

=head2 get_cache_type

Sets and gets the value of the C<$cache_type> configuration variable, which can also be controlled via the C<REX_CACHE_TYPE> environment variable.

This selects the cache type Rex should use, e.g. C<'YAML'>.

Default is C<'Base'>.

=cut

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

=head2 set_use_cache

=head2 get_use_cache

Sets and gets the value of the C<$use_cache> configuration variable.

This controls whether Rex should use caching or not for runtime information like CMDB contents, hardware and operating system information, or the shell type that is being used to execute commands on the managed endpoint.

Default is C<undef>.

=cut

sub set_use_cache {
  my $class = shift;
  $use_cache = shift;
}

sub get_use_cache {
  return $use_cache;
}

=head2 set_openssh_opt

=head2 get_openssh_opt

Sets and gets the value of the C<$openssh_opt> configuration variable, which holds a hash of the SSH configuration options used for the connection. See the L<ssh_config(5) man page|http://man.openbsd.org/OpenBSD-current/man5/ssh_config.5> for the available options.

  Rex::Config->set_openssh_opt( $option => $value, );

There is a custom option named C<initialize_options> specific to Rex, which can be used to pass a hash reference describing the L<constructor parameters|https://metacpan.org/pod/Net::OpenSSH#Net::OpenSSH-E<gt>new($host,-%opts)> for the underlying L<Net::OpenSSH> object:

 Rex::Config->set_openssh_opt( initialize_options => { $parameter => $value, } );

Default is C<undef>.

=cut

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

=head2 set_sudo_without_locales

=head2 get_sudo_without_locales

Sets and gets the value of the C<$sudo_without_locales> configuration variable.

This controls whether Rex should execute L<sudo|Rex::Commands::Run#sudo> commands without setting any locales via the C<LC_ALL> environment variable.

B<Warning:> if the locale is something else than C<C> or C<en_US>, then things will break!

Default is C<undef>.

=cut

sub set_sudo_without_locales {
  my $class = shift;
  $sudo_without_locales = shift;
}

sub get_sudo_without_locales {
  return $sudo_without_locales;
}

=head2 set_sudo_without_sh

=head2 get_sudo_without_sh

Sets and gets the value of the C<$sudo_without_sh> configuration variable.

This controls whether Rex should run L<sudo|Rex::Commands::Run#sudo> commands without C<sh>. This might break things.

Default is C<undef>.

=cut

sub set_sudo_without_sh {
  my $class = shift;
  $sudo_without_sh = shift;
}

sub get_sudo_without_sh {
  return $sudo_without_sh;
}

=head2 set_executor_for

=head2 get_executor_for

Sets and gets the keys and values of the C<%executor_for> configuration variable.

This sets the executor for a given file type when using the C<upload_and_run()> function of L<Rex::Helper::Run> module.

Default is:

 (
   perl   => 'perl',
   python => 'python',
   ruby   => 'ruby',
   bash   => 'bash',
 )

=cut

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

=head2 set_tmp_dir

=head2 get_tmp_dir

Sets and gets the value of the C<$tmp_dir> configuration variable.

This controls which directory Rex should use for temporary files.

Default is determined by the following logic:

=over 4

=item * try to use what C<< File::Spec->tmpdir >> would return on the managed endpoint

=item * fall back to C<'/tmp'>

=back

=cut

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

=head2 set_path

=head2 get_path

Sets and gets the value of the C<$path> configuration variable.

This controls which C<PATH> Rex should use when executing L<run|Rex::Commands::Run#run> commands. The value should be set as an array reference, and will be dereferenced as such before returned by C<get_path>.

Default is

 qw(
   /bin
   /sbin
   /usr/bin
   /usr/sbin
   /usr/local/bin
   /usr/local/sbin
   /usr/pkg/bin
   /usr/pkg/sbin
 )

=cut

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

=head2 set_user

=head2 get_user

Sets and gets the value of the C<$user> configuration variable, which also can be set via the C<REX_USER> environment variable.

This controls which L<user|Rex::Commands#user> Rex should use for authentication.

Default is determined by the following logic:

=over 4

=item * value of C<REX_USER> environment variable

=item * user set by L<user|Rex::Commands#user> command

=item * user running Rex

=back

=cut

sub set_user {
  my $class = shift;
  $user = shift;
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

  if ( $^O =~ m/^MSWin/ ) {
    return getlogin;
  }
  else {
    return scalar getpwuid($<);
  }
}

=head2 set_password

=head2 get_password

Sets and gets the value of the C<$password> configuration variable, which also can be set via the C<REX_PASSWORD> environment variable.

This controls what L<password|Rex::Commands#password> Rex should use for authentication or as passphrase when using private keys.

Default is C<undef>.

=cut

sub set_password {
  my $class = shift;
  $password = shift;
}

sub get_password {
  my $class = shift;

  if ( exists $ENV{REX_PASSWORD} ) {
    return $ENV{REX_PASSWORD};
  }

  return $password;
}

=head2 set_port

=head2 get_port

Sets and gets the value of the C<$port> configuration variable.

This controls which L<port|Rex::Commands#port> Rex should connect to.

C<get_port> accepts an optional C<< server => $server >> argument to return the C<port> setting for the given C<$server> as optionally set in group files.

Default is C<undef>.

=cut

sub set_port {
  my $class = shift;
  $port = shift;
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

=head2 set_sudo_password

=head2 get_sudo_password

Sets and gets the value of the C<$sudo_password> configuration variable, which can also be controlled via the C<REX_SUDO_PASSWORD> environment variable.

This controls what L<sudo password|Rex::Commands#sudo_password> Rex should use.

Default is determined by the following logic:

=over 4

=item * value of C<REX_SUDO_PASSWORD> environment variable

=item * sudo password set by the L<sudo_password|Rex::Command#sudo_password> command

=item * password set by the L<password|Rex::Command#password> command

=item * empty string (C<''>)

=back

=cut

sub set_sudo_password {
  my $class = shift;
  $sudo_password = shift;
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

=head2 set_source_global_profile

=head2 get_source_global_profile

Sets and gets the value of the C<$source_global_profile> configuration variable.

This controls whether Rex should source C</etc/profile> before executing commands.

Default is C<undef>.

=cut

sub set_source_global_profile {
  my $class = shift;
  $source_global_profile = shift;
}

sub get_source_global_profile {
  return $source_global_profile;
}

=head2 set_max_connect_fails

=head2 get_max_connect_fails

Sets and gets the value of the C<$max_connect_fails> configuration variable.

This controls how many times Rex should retry to connect before giving up.

C<get_max_connect_fails> accepts an optional C<< server => $server >> argument to C<connectionattempts> setting for the given C<$server> as optionally set in group files.

Default is C<undef>.

=cut

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

=head2 set_proxy_command

=head2 get_proxy_command

Sets and gets the value of the C<$proxy_command> configuration variable.

This controls the SSH ProxyCommand Rex should set for connections when L<Net::OpenSSH> is used.

C<get_proxy_command> accepts an optional C<< server => $server >> argument to return the C<proxycommand> setting for the given C<$server> as optionally set in group files.

Default is C<undef>.

=cut

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

=head2 set_timeout

=head2 get_timeout

Sets and gets the value of the C<$timeout> configuration variable.

This controls how many seconds Rex should wait for connections to succeed when using SSH or L<Rex::Commands::Rsync>.

C<get_timeout> accepts an optional C<< server => $server >> argument to return the C<connecttimeout> setting for the given C<$server> as optionally set in group files.

Default is C<undef>.

=cut

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

=head2 set_password_auth

=head2 get_password_auth

Sets and gets the value of the C<$password_auth> configuration variable, which can also be set by setting the C<REX_AUTH_TYPE> environment variable to C<pass>.

This controls whether Rex should use the L<password authentication|Rex::Commands#pass_auth> method.

Default is C<undef>.

=cut

sub set_password_auth {
  my $class = shift;
  $key_auth      = 0;
  $krb5_auth     = 0;
  $password_auth = shift || 1;
}

sub get_password_auth {
  if ( exists $ENV{REX_AUTH_TYPE} && $ENV{REX_AUTH_TYPE} eq "pass" ) {
    return 1;
  }
  return $password_auth;
}

=head2 set_key_auth

=head2 get_key_auth

Sets and gets the value of the C<$key_auth> configuration variable, which can also be set by setting the C<REX_AUTH_TYPE> environment variable to C<key>.

This controls whether Rex should use the L<key authentication|Rex::Commands#key_auth> method.

Default is C<undef>.

=cut

sub set_key_auth {
  my $class = shift;
  $password_auth = 0;
  $krb5_auth     = 0;
  $key_auth      = shift || 1;
}

sub get_key_auth {
  if ( exists $ENV{REX_AUTH_TYPE} && $ENV{REX_AUTH_TYPE} eq "key" ) {
    return 1;
  }
  return $key_auth;
}

=head2 set_krb5_auth

=head2 get_krb5_auth

Sets and gets the value of the C<$krb5_auth> configuration variable, which can also be set by setting the C<REX_AUTH_TYPE> environment variable to C<krb5>.

This controls whether Rex should use the L<Kerberos 5|Rex::Commands#krb5_auth> authentication method.

Default is C<undef>.

=cut

sub set_krb5_auth {
  my $class = shift;
  $password_auth = 0;
  $key_auth      = 0;
  $krb5_auth     = shift || 1;
}

sub get_krb5_auth {
  if ( exists $ENV{REX_AUTH_TYPE} && $ENV{REX_AUTH_TYPE} eq "krb5" ) {
    return 1;
  }
  return $krb5_auth;
}

=head2 set_public_key

=head2 get_public_key

Sets and gets the value of the C<$public_key> configuration variable.

This controls which L<public key|Rex::Commands#public_key> Rex should use when using L<Net::SSH2> for connections.

Default is C<undef>.

=cut

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

=head2 set_private_key

=head2 get_private_key

Sets and gets the value of the C<$private_key> configuration variable.

This controls which L<private key|Rex::Commands#private_key> Rex should use with L<Rex::Commands::Rsync> or when using L<Net::SSH2> for connections.

Default is C<undef>.

=cut

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

=head2 set_parallelism

=head2 get_parallelism

Sets and gets the value of the C<$parallelism> configuration variable.

This controls how many hosts Rex should connect to in L<parallel|Rex::Commands#parallelism>.

Default is C<1>.

=cut

sub set_parallelism {
  my $class = shift;
  $parallelism = $_[0];
}

sub get_parallelism {
  my $class = shift;
  return $parallelism || 1;
}

=head2 set_log_filename

=head2 get_log_filename

Sets and gets the value of the C<$log_filename> configuration variable.

This controls which file Rex should use for L<logging|Rex::Commands#logging>.

Default is C<undef>.

=cut

sub set_log_filename {
  my $class = shift;
  $log_filename = shift;
}

sub get_log_filename {
  my $class = shift;
  return $log_filename;
}

=head2 set_log_facility

=head2 get_log_facility

Sets and gets the value of the C<$log_facility> configuration variable.

This controls which log facility Rex should use when L<logging|Rex::Commands#logging> to syslog.

Default is C<'local0'>.

=cut

sub set_log_facility {
  my $class = shift;
  $log_facility = shift;
}

sub get_log_facility {
  my $class = shift;
  return $log_facility || "local0";
}

=head2 set_environment

=head2 get_environment

Sets and gets the value of the C<$environment> configuration variable.

This controls which L<environment|Rex::Commands#environment> Rex should use.

Default is C<''>.

=cut

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
    if ( $SSH_CONFIG_FOR{ $param->{server} }->{hostname} =~ m/^\%h(\.(.*))?/ ) {
      return $param->{server} . $1;
    }
    else {
      return $SSH_CONFIG_FOR{ $param->{server} }->{hostname};
    }
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

=head2 set_distributor

=head2 get_distributor

Sets and gets the value of the C<$distributor> configuration variable.

This controls which method Rex should use for distributing tasks for parallel execution.

Default is C<'Base'>.

=cut

sub set_distributor {
  my $class = shift;
  $distributor = shift;
}

sub get_distributor {
  my $class = shift;
  return $distributor || "Base";
}

=head2 set_template_function

=head2 get_template_function

Sets and gets the value of the C<$template_function> configuration variable.

This controls the function to be used for rendering L<templates|Rex::Commands::File#template>. The value should be a subroutine reference that will be called with passing two scalar references as positional arguments: first is template content, second is template variables.

Default is determined by the following logic:

=over 4

=item * if L<Rex::Template::NG> is loadable and L<use_template_ng|Rex::Config#get_use_template_ng> is true, use that

=item * fall back to L<Rex::Template> otherwise

=back

=cut

sub set_template_function {
  my $class = shift;
  ($template_function) = @_;
}

sub get_template_function {
  if ( ref($template_function) eq "CODE" ) {
    return sub {
      my ( $content, $template_vars ) = @_;
      $template_vars = {
        Rex::Commands::task()->get_opts,
        (
          Rex::Resource->is_inside_resource
          ? %{ Rex::Resource->get_current_resource()->get_all_parameters }
          : ()
        ),
        %{ $template_vars || {} }
        }
        if ( Rex::Commands::task() );
      return $template_function->( $content, $template_vars );
    };
  }

  if ( Rex::Template::NG->is_loadable && get_use_template_ng() ) {

    # new template engine
    return sub {
      my ( $content, $template_vars ) = @_;
      $template_vars = {
        Rex::Commands::task()->get_opts,
        (
          Rex::Resource->is_inside_resource
          ? %{ Rex::Resource->get_current_resource()->get_all_parameters }
          : ()
        ),
        %{ $template_vars || {} }
        }
        if ( Rex::Commands::task() );
      Rex::Template::NG->require;
      my $t = Rex::Template::NG->new;
      return $t->parse( $content, %{$template_vars} );
    };
  }

  return sub {
    my ( $content, $template_vars ) = @_;
    $template_vars = {
      Rex::Commands::task()->get_opts,
      (
        Rex::Resource->is_inside_resource
        ? %{ Rex::Resource->get_current_resource()->get_all_parameters }
        : ()
      ),
      %{ $template_vars || {} }
      }
      if ( Rex::Commands::task() );
    use Rex::Template;
    my $template = Rex::Template->new;
    return $template->parse( $content, $template_vars );
  };
}

=head2 set_no_tty

=head2 get_no_tty

Sets and gets the value of the C<$no_tty> configuration variable.

This controls whether Rex should request a terminal when using L<Net::SSH2> or allocate a pseudo-tty for the remote process when using L<Net::OpenSSH>.

Default is C<undef>.

=cut

sub set_no_tty {
  shift;
  $no_tty = shift;
}

sub get_no_tty {
  return $no_tty;
}

=head2 set_allow_empty_groups

=head2 get_allow_empty_groups

Sets and gets the value of the C<$allow_empty_groups> configuration variable.

This controls whether Rex should allow empty L<groups of hosts|Rex::Commands#group> or not.

Default is C<0>.

=cut

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

=head2 set_use_server_auth

=head2 get_use_server_auth

Sets and gets the value of the C<$use_server_auth> configuration variable.

This controls whether Rex should use server-specific authentication information from group files.

Default is C<0>.

=cut

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

=head2 set_waitpid_blocking_sleep_time

=head2 get_waitpid_blocking_sleep_time

Sets and gets the value of the C<$waitpid_blocking_sleep_time> configuration variable.

This controls how many seconds Rex should sleep between checking forks.

Default is C<0.1>.

=cut

sub set_waitpid_blocking_sleep_time {
  my $self = shift;
  $waitpid_blocking_sleep_time = shift;
}

sub get_waitpid_blocking_sleep_time {
  return $waitpid_blocking_sleep_time // 0.1;
}

=head2 set_write_utf8_files

=head2 get_write_utf8_files

Sets and gets the value of the C<$write_utf8_files> configuration variable.

This controls whether Rex should force C<UTF-8> encoding when writing files.

Default is C<undef>.

=cut

sub set_write_utf8_files {
  my $self = shift;
  $write_utf8_files = shift;
}

sub get_write_utf8_files {
  return $write_utf8_files;
}

=head2 set_default_auth

=head2 get_default_auth

Sets and gets the value of the C<$default_auth> configuration variable.

This controls whether Rex should attach default authentication info to tasks.

Default is C<1>.

=cut

sub set_default_auth {
  my $self = shift;
  $default_auth = shift;
}

sub get_default_auth {
  return $default_auth // 1;
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

With this function it is possible to register own sections in the users config file (C<$HOME/.rex/config.yml>).

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
      @host    = split( /\s+/, $host_tmp );
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

sub import {
  read_ssh_config_file();
  read_config_file();
}

_register_config_handlers();

sub _register_config_handlers {
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

        my $ref_to_key        = qualify_to_ref( $key, __PACKAGE__ );
        my $ref_to_key_scalar = *{$ref_to_key}{SCALAR};

        ${$ref_to_key_scalar} = $param->{$key};
      }
    }
  );
}

_register_set_handlers();

sub _register_set_handlers {
  my @set_handler =
    qw/user password private_key public_key -keyauth -passwordauth -passauth
    parallelism sudo_password connection ca cert key distributor
    template_function port waitpid_blocking_sleep_time/;
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

        my $ref_to_hndl        = qualify_to_ref( $hndl, __PACKAGE__ );
        my $ref_to_hndl_scalar = *{$ref_to_hndl}{SCALAR};

        ${$ref_to_hndl_scalar} = $val;
      }
    );
  }
}

sub _home_dir {
  if ( $^O =~ m/^MSWin/ ) {
    return $ENV{'USERPROFILE'};
  }

  return $ENV{'HOME'} || "";
}

1;
