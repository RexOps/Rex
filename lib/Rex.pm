#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=encoding UTF-8

=head1 NAME

Rex - the friendly automation framework

=head1 DESCRIPTION

Rex is an automation framework that is friendly to any combinations of local
and remote execution, push and pull style of management, or imperative and
declarative approach.

Its flexibility makes it a great fit for many different use cases, but most
commonly Rex is used to automate application deployment and data center
infrastructure management tasks.

See L<Rex::Commands> for a starting point of available built-in commands.

See L<rex|https://metacpan.org/pod/distribution/Rex/bin/rex> for more information about how to use rex on the command line.

=head1 SYNOPSIS

    # In a Rexfile:
    use Rex -feature => [qw/1.4/];
   
    user "root";
    password "ch4ngem3";
   
    desc "Show system information";
    task "sysinfo", sub {
       say run "uname -a";
    };

    1;
   
    # On the command line:
    $ rex -H server[01..10] sysinfo

=head1 CLASS METHODS

=cut

package Rex;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  use Rex::Logger;
  use Rex::Interface::Cache;
  use Data::Dumper;
  use Rex::Interface::Connection;
  use Cwd qw(getcwd);
  use Rex::Config;
  use Rex::Helper::Array;
  use Rex::Report;
  use Rex::Notify;
  use Rex::Require;
  use File::Basename;
  use File::Spec;
  eval { Net::SSH2->require; };
}

our ( @EXPORT, @CONNECTION_STACK, $GLOBAL_SUDO, $MODULE_PATHS,
  $WITH_EXIT_STATUS, @FEATURE_FLAGS );

$WITH_EXIT_STATUS = 1; # since 0.50 activated by default
@FEATURE_FLAGS    = ();

BEGIN {

  sub generate_inc {
    my @additional = @_;

    my @rex_inc = ();

# this must be the first, special handling for rex modules which uses Module.pm and not
# __module__.pm as their initial file. (rex pre 0.40 or something)
    push @rex_inc, sub {
      my $mod_to_load = $_[1];
      return search_module_path( $mod_to_load, 1 );
    };

# this adds the current directory to the lib search path.
# this must come before all other paths, because custom libraries can be project dependant
# see: #1108
    push @rex_inc, add_cwd_to_inc();
    push @rex_inc, add_libstruct_to_inc($_) for @additional;

    # we have to add the Rexfile's path to @INC FIX: #1170
    push @rex_inc, @additional;

# add home directory/.rex/recipes to the search path, so that recipes can be managed
# at a central location.
    my $home_dir = _home_dir();
    if ( -d "$home_dir/.rex/recipes" ) {
      push( @INC, "$home_dir/.rex/recipes" );
    }

    # add the default search locations
    push @rex_inc, @INC;

    # this must be the last entry, special handling to load rex modules.
    push(
      @rex_inc,
      sub {
        my $mod_to_load = $_[1];
        return search_module_path( $mod_to_load, 0 );
      }
    );

    return @rex_inc;
  }

  sub add_libstruct_to_inc {
    my ($path) = @_;
    my @ret = ();

    if ( -d File::Spec->catdir( $path, "lib" ) ) {
      push( @ret, File::Spec->catdir( $path, "lib" ) );
      push( @ret, File::Spec->catdir( $path, "lib", "perl", "lib", "perl5" ) );
      if ( $^O eq "linux" ) {
        push(
          @ret,
          File::Spec->catdir(
            $path, "lib", "perl", "lib", "perl5", "x86_64-linux"
          )
        );
      }
      if ( $^O =~ m/^MSWin/ ) {
        my ($special_win_path) = grep { m/\/MSWin32\-/ } @INC;
        if ( defined $special_win_path ) {
          my $mswin32_path = basename $special_win_path;
          push(
            @ret,
            File::Spec->catdir(
              $path, "lib", "perl", "lib", "perl5", $mswin32_path
            )
          );
        }
      }
    }

    return @ret;
  }

  sub add_cwd_to_inc {
    my $path = getcwd;
    return add_libstruct_to_inc($path);
  }

  sub _home_dir {
    if ( $^O =~ m/^MSWin/ ) {
      return $ENV{'USERPROFILE'};
    }

    return $ENV{'HOME'} || "";
  }

  my @new_inc = generate_inc();
  @INC = @new_inc;

}

my $home = $ENV{'HOME'} || "/tmp";
if ( $^O =~ m/^MSWin/ ) {
  $home = $ENV{'USERPROFILE'};
}

push( @INC, "$home/.rex/recipes" );

sub search_module_path {
  my ( $mod_to_load, $pre ) = @_;

  $mod_to_load =~ s/\.pm//g;

  my @search_in;
  if ($pre) {
    @search_in = map { ("$_/$mod_to_load.pm") }
      grep { -d } @INC;

  }
  else {
    @search_in =
      map { ( "$_/$mod_to_load/__module__.pm", "$_/$mod_to_load/Module.pm" ) }
      grep { -d } @INC;
  }

  for my $file (@search_in) {
    my $o = -f $file;
    my $fh_t;
    if ( $^O =~ m/^MSWin/i && !$o ) {

      # this is a windows workaround for if(-f ) on symlinks
      $o = open( my $fh_t, "<", $file );
    }

    if ($o) {
      close $fh_t if $fh_t;
      my ($path) = ( $file =~ m/^(.*)\/.+?$/ );
      if ( $path !~ m/\// ) {
        $path = getcwd() . "/$path";
      }

      # module found, register path
      $MODULE_PATHS->{$mod_to_load} = { path => $path };
      my $mod_package_name = $mod_to_load;
      $mod_package_name =~ s/\//::/g;
      $MODULE_PATHS->{$mod_package_name} = { path => $path };

      if ($pre) {
        return;
      }

      open( my $fh, "<", $file );
      return $fh;
    }
  }
}

sub get_module_path {
  my ($module) = @_;
  if ( exists $MODULE_PATHS->{$module} ) {
    return $MODULE_PATHS->{$module}->{path};
  }
}

sub push_connection {
  if ( !ref $_[0]->{server} ) {
    $_[0]->{server} = Rex::Group::Entry::Server->new( name => $_[0]->{server} );
  }

  push @CONNECTION_STACK, $_[0];
  return $_[0];
}

sub pop_connection {
  pop @CONNECTION_STACK;
  Rex::Logger::debug( "Connections in queue: " . scalar(@CONNECTION_STACK) );
}

sub reconnect_lost_connections {
  if ( @CONNECTION_STACK > 0 ) {
    Rex::Logger::debug("Need to reinitialize connections.");
    for (@CONNECTION_STACK) {
      $_->{conn}->reconnect;
    }
  }
}

# ... no words
my @__modif_caller;

sub unset_modified_caller {
  @__modif_caller = ();
}

sub modified_caller {
  my (@caller) = @_;
  if (@caller) {
    @__modif_caller = @caller;
  }
  else {
    return @__modif_caller;
  }
}

=head2 get_current_connection

This function is deprecated since 0.28! See Rex::Commands::connection.

Returns the current connection as a hashRef.

=over 4

=item server

The server name

=item ssh

1 if it is a ssh connection, 0 if not.

=back

=cut

sub get_current_connection {

  # if no connection available, use local connect
  unless (@CONNECTION_STACK) {
    my $conn = Rex::Interface::Connection->create("Local");

    Rex::push_connection(
      {
        conn     => $conn,
        ssh      => $conn->get_connection_object,
        cache    => Rex::Interface::Cache->create(),
        reporter => Rex::Report->create(),
        notify   => Rex::Notify->new(),
      }
    );
  }

  $CONNECTION_STACK[-1];
}

sub get_current_connection_object {
  return Rex::get_current_connection()->{conn};
}

=head2 is_ssh

Returns 1 if the current connection is a ssh connection. 0 if not.

=cut

sub is_ssh {
  if ( $CONNECTION_STACK[-1] ) {
    my $ref = ref( $CONNECTION_STACK[-1]->{"conn"} );
    if ( $ref =~ m/SSH/ ) {
      return $CONNECTION_STACK[-1]->{"conn"}->get_connection_object();
    }
  }

  return 0;
}

=head2 is_local

Returns 1 if the current connection is local. Otherwise 0.

=cut

sub is_local {
  if ( $CONNECTION_STACK[-1] ) {
    my $ref = ref( $CONNECTION_STACK[-1]->{"conn"} );
    if ( $ref =~ m/Local/ ) {
      return $CONNECTION_STACK[-1]->{"conn"}->get_connection_object();
    }
  }

  return 0;
}

=head2 is_sudo

Returns 1 if the current operation is executed within sudo.

=cut

sub is_sudo {

  if ( exists $CONNECTION_STACK[-1]->{server}->{auth}->{sudo}
    && $CONNECTION_STACK[-1]->{server}->{auth}->{sudo} == 1 )
  {
    return 1;
  }
  elsif ( exists $CONNECTION_STACK[-1]->{server}->{auth}->{sudo}
    && $CONNECTION_STACK[-1]->{server}->{auth}->{sudo} == 0 )
  {
    return 0;
  }

  if ($GLOBAL_SUDO) { return 1; }

  if ( $CONNECTION_STACK[-1] ) {
    return $CONNECTION_STACK[-1]->{conn}->get_current_use_sudo;
  }

  return 0;
}

sub global_sudo {
  my ($on) = @_;
  $GLOBAL_SUDO = $on;

  # turn cache on
  Rex::Config->set_use_cache(1);
}

=head2 get_sftp

Returns the sftp object for the current ssh connection.

=cut

sub get_sftp {
  if ( $CONNECTION_STACK[-1] ) {
    return $CONNECTION_STACK[-1]->{"conn"}->get_fs_connection_object();
  }

  return 0;
}

sub get_cache {
  if ( $CONNECTION_STACK[-1] ) {
    return $CONNECTION_STACK[-1]->{"cache"};
  }

  return Rex::Interface::Cache->create();
}

=head2 connect

Use this function to create a connection if you use Rex as a library.

 use Rex;
 use Rex::Commands::Run;
 use Rex::Commands::Fs;

 Rex::connect(
   server    => "remotehost",
   user      => "root",
   password   => "f00b4r",
   private_key => "/path/to/private/key/file",
   public_key  => "/path/to/public/key/file",
 );

 if(is_file("/foo/bar")) {
   print "Do something...\n";
 }

 my $output = run("uptime");

=cut

sub connect {

  my ($param) = {@_};

  my $server      = $param->{server};
  my $port        = $param->{port}    || 22;
  my $timeout     = $param->{timeout} || 5;
  my $user        = $param->{"user"};
  my $pass        = $param->{"password"};
  my $cached_conn = $param->{"cached_connection"};

  if ( !$cached_conn ) {
    my $conn =
      Rex::Interface::Connection->create(Rex::Config::get_connection_type);

    $conn->connect(
      user     => $user,
      password => $pass,
      server   => $server,
      port     => $port,
      timeout  => $timeout,
      %{$param},
    );

    unless ( $conn->is_connected ) {
      die("Connection error or refused.");
    }

    # push a remote connection
    my $rex_conn = Rex::push_connection(
      {
        conn     => $conn,
        ssh      => $conn->get_connection_object,
        server   => $server,
        cache    => Rex::Interface::Cache->create(),
        reporter => Rex::Report->create( Rex::Config->get_report_type ),
        notify   => Rex::Notify->new(),
      }
    );

    # auth unsuccessfull
    unless ( $conn->is_authenticated ) {
      Rex::Logger::info( "Wrong username or password. Or wrong key.", "warn" );

      # after jobs

      die("Wrong username or password. Or wrong key.");
    }

    return $rex_conn;
  }
  else {
    Rex::push_connection($cached_conn);
    return $cached_conn;
  }

}

sub deprecated {
  my ( $func, $version, @msg ) = @_;

  if ($func) {
    Rex::Logger::info("The call to $func is deprecated.");
  }

  if (@msg) {
    for (@msg) {
      Rex::Logger::info($_);
    }
  }

  Rex::Logger::info("");

  Rex::Logger::info(
    "Please rewrite your code. This function will disappear in (R)?ex version $version."
  );
  Rex::Logger::info(
    "If you need assistance please join #rex on irc.freenode.net or our google group."
  );

}

sub has_feature_version {
  my ($version) = @_;

  my @version_flags = grep { m/^\d+\./ } @FEATURE_FLAGS;
  for my $v (@version_flags) {
    if ( $version <= $v ) {
      return 1;
    }
  }

  return 0;
}

sub has_feature_version_lower {
  my ($version) = @_;

  my @version_flags = grep { m/^\d+\./ } @FEATURE_FLAGS;
  for my $v (@version_flags) {
    if ( $version > $v ) {
      return 1;
    }
  }

  return 0;
}

sub import {
  my ( $class, $what, $addition1 ) = @_;

  srand();

  if ( $addition1 && ref $addition1 eq "ARRAY" ) {
    push @FEATURE_FLAGS, $what, @{$addition1};
  }
  elsif ($addition1) {
    push @FEATURE_FLAGS, $what, $addition1;
  }

  $what ||= "";

  my ( $register_to, $file, $line ) = caller;

  # use Net::OpenSSH if present (default without feature flag)
  Rex::Config->set_use_net_openssh_if_present(1);

  if ( $what eq "-minimal" ) {
    require Rex::Commands;
    Rex::Commands->import( register_in => $register_to );

    require Rex::Helper::Rexfile::ParamLookup;
    Rex::Helper::Rexfile::ParamLookup->import( register_in => $register_to );
  }

  if ( $what eq "-base" || $what eq "base" || $what eq "-feature" ) {
    require Rex::Commands;
    Rex::Commands->import( register_in => $register_to );

    require Rex::Commands::Run;
    Rex::Commands::Run->import( register_in => $register_to );

    require Rex::Commands::Fs;
    Rex::Commands::Fs->import( register_in => $register_to );

    require Rex::Commands::File;
    Rex::Commands::File->import( register_in => $register_to );

    require Rex::Commands::Cron;
    Rex::Commands::Cron->import( register_in => $register_to );

    require Rex::Commands::Host;
    Rex::Commands::Host->import( register_in => $register_to );

    require Rex::Commands::Download;
    Rex::Commands::Download->import( register_in => $register_to );

    require Rex::Commands::Upload;
    Rex::Commands::Upload->import( register_in => $register_to );

    require Rex::Commands::Gather;
    Rex::Commands::Gather->import( register_in => $register_to );

    require Rex::Commands::Kernel;
    Rex::Commands::Kernel->import( register_in => $register_to );

    require Rex::Commands::Pkg;
    Rex::Commands::Pkg->import( register_in => $register_to );

    require Rex::Commands::Service;
    Rex::Commands::Service->import( register_in => $register_to );

    require Rex::Commands::Sysctl;
    Rex::Commands::Sysctl->import( register_in => $register_to );

    require Rex::Commands::Tail;
    Rex::Commands::Tail->import( register_in => $register_to );

    require Rex::Commands::Process;
    Rex::Commands::Process->import( register_in => $register_to );

    require Rex::Commands::Sync;
    Rex::Commands::Sync->import( register_in => $register_to );

    require Rex::Commands::Notify;
    Rex::Commands::Notify->import( register_in => $register_to );

    require Rex::Commands::User;
    Rex::Commands::User->import( register_in => $register_to );

    require Rex::Helper::Rexfile::ParamLookup;
    Rex::Helper::Rexfile::ParamLookup->import( register_in => $register_to );

    require Rex::Resource::firewall;
    Rex::Resource::firewall->import( register_in => $register_to );
  }

  if ( $what eq "-feature" || $what eq "feature" ) {

    if ( !ref($addition1) ) {
      $addition1 = [$addition1];
    }
    for my $add ( @{$addition1} ) {

      my $found_feature = 0;

      if ( $add =~ m/^(\d+\.\d+)$/ ) {
        my $vers = $1;
        my ( $major, $minor, $patch, $dev_release ) =
          $Rex::VERSION =~ m/^(\d+)\.(\d+)\.(\d+)[_.]?(\d+)?$/;

        my ( $c_major, $c_minor ) = split( /\./, $vers );

        if ( defined $dev_release && $c_major == $major && $c_minor > $minor ) {
          Rex::Logger::info(
            "This is development release $Rex::VERSION of Rex. Enabling experimental feature flag for $vers.",
            "warn"
          );
        }
        elsif ( ( $c_major > $major )
          || ( $c_major >= $major && $c_minor > $minor ) )
        {
          Rex::Logger::info(
            "This Rexfile tries to enable features that are not supported with your version. Please update.",
            "error"
          );
          exit 1;
        }
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 1.4 ) {
        Rex::Logger::debug("Enabling task_chaining_cmdline_args feature");
        Rex::Config->set_task_chaining_cmdline_args(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 1.3 ) {
        Rex::Logger::debug("Activating new template engine.");
        Rex::Config->set_use_template_ng(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 1.0 ) {
        Rex::Logger::debug("Disabling usage of a tty");
        Rex::Config->set_no_tty(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.56 ) {
        Rex::Logger::debug("Activating autodie.");
        Rex::Config->set_autodie(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.55 ) {
        Rex::Logger::debug("Using Net::OpenSSH if present.");
        Rex::Config->set_use_net_openssh_if_present(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.54 ) {
        Rex::Logger::debug("Add service check.");
        Rex::Config->set_check_service_exists(1);

        Rex::Logger::debug("Setting set() to not append data.");
        Rex::Config->set_set_no_append(1);

        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.53 ) {
        Rex::Logger::debug("Registering CMDB as template variables.");
        Rex::Config->set_register_cmdb_template(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.51 ) {
        Rex::Logger::debug("activating featureset >= 0.51");
        Rex::Config->set_task_call_by_method(1);

        require Rex::Constants;
        Rex::Constants->import( register_in => $register_to );

        require Rex::CMDB;
        Rex::CMDB->import( register_in => $register_to );

        Rex::Commands::set(
          cmdb => {
            type => "YAML",
            path => [
              "cmdb/{operatingsystem}/{hostname}.yml",
              "cmdb/{operatingsystem}/default.yml",
              "cmdb/{environment}/{hostname}.yml",
              "cmdb/{environment}/default.yml",
              "cmdb/{hostname}.yml",
              "cmdb/default.yml",
            ],
          }
        );

        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.40 ) {
        Rex::Logger::debug("activating featureset >= 0.40");
        $Rex::Template::BE_LOCAL = 1;
        $Rex::WITH_EXIT_STATUS   = 1;
        $found_feature           = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.35 ) {
        Rex::Logger::debug("activating featureset >= 0.35");
        $Rex::Commands::REGISTER_SUB_HASH_PARAMETER = 1;
        $found_feature                              = 1;
      }

      # remove default task auth
      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.31 ) {
        Rex::Logger::debug("activating featureset >= 0.31");
        Rex::Config->set_default_auth(0);
        $found_feature = 1;
      }

      if ( $add eq 'autodie' ) {
        Rex::Logger::debug('enabling autodie');
        Rex::Config->set_autodie(1);
        $found_feature = 1;
      }

      if ( $add eq "no_autodie" ) {
        Rex::Logger::debug("disabling autodie");
        Rex::Config->set_autodie(0);
        $found_feature = 1;
      }

      if ( $add eq "rex_kvm_agent" ) {
        Rex::Logger::debug(
          "Activating experimental support for rex-kvm-agent.");
        Rex::Config->set_use_rex_kvm_agent(1);
        $found_feature = 1;
      }

      if ( $add eq "template_ng" ) {
        Rex::Logger::debug("Activating new template engine.");
        Rex::Config->set_use_template_ng(1);
        $found_feature = 1;
      }

      if ( $add eq "no_template_ng" ) {
        Rex::Logger::debug("Deactivating new template engine.");
        Rex::Config->set_use_template_ng(0);
        $found_feature = 1;
      }

      if ( $add eq "register_cmdb_top_scope" ) {
        Rex::Logger::debug("Registering CMDB as template variables.");
        Rex::Config->set_register_cmdb_template(1);
        $found_feature = 1;
      }

      if ( $add eq "no_local_template_vars" ) {
        Rex::Logger::debug("activating featureset no_local_template_vars");
        $Rex::Template::BE_LOCAL = 0;
        $found_feature           = 1;
      }

      if ( $add eq "exit_status" ) {
        Rex::Logger::debug("activating featureset exit_status");
        $Rex::WITH_EXIT_STATUS = 1;
        $found_feature         = 1;
      }

      if ( $add eq "sudo_without_sh" ) {
        Rex::Logger::debug(
          "using sudo without sh. this might break some things.");
        Rex::Config->set_sudo_without_sh(1);
        $found_feature = 1;
      }

      if ( $add eq "sudo_without_locales" ) {
        Rex::Logger::debug(
          "Using sudo without locales. this _will_ break things!");
        Rex::Config->set_sudo_without_locales(1);
        $found_feature = 1;
      }

      if ( $add eq "tty" ) {
        Rex::Logger::debug("Enabling pty usage for ssh");
        Rex::Config->set_no_tty(0);
        $found_feature = 1;
      }

      if ( $add eq "no_tty" ) {
        Rex::Logger::debug("Disabling pty usage for ssh");
        Rex::Config->set_no_tty(1);
        $found_feature = 1;
      }

      if ( $add eq "empty_groups" ) {
        Rex::Logger::debug("Enabling usage of empty groups");
        Rex::Config->set_allow_empty_groups(1);
        $found_feature = 1;
      }

      if ( $add eq "use_server_auth" ) {
        Rex::Logger::debug("Enabling use_server_auth");
        Rex::Config->set_use_server_auth(1);
        $found_feature = 1;
      }

      if ( $add eq "exec_and_sleep" ) {
        Rex::Logger::debug("Enabling exec_and_sleep");
        Rex::Config->set_sleep_hack(1);
        $found_feature = 1;
      }

      if ( $add eq "disable_strict_host_key_checking" ) {
        Rex::Logger::debug("Disabling strict host key checking for openssh");
        Rex::Config->set_openssh_opt( StrictHostKeyChecking => "no" );
        $found_feature = 1;
      }

  #if($add eq "reporting" || $add eq "report" || exists $ENV{REX_REPORT_TYPE}) {
  #  Rex::Logger::debug("Enabling reporting");
      Rex::Config->set_do_reporting(1);

      #  $found_feature = 1;
      #}

      if ( $add eq "source_profile" ) {
        Rex::Logger::debug("Enabling source_profile");
        Rex::Config->set_source_profile(1);
        $found_feature = 1;
      }

      if ( $add eq "source_global_profile" ) {
        Rex::Logger::debug("Enabling source_global_profile");
        Rex::Config->set_source_global_profile(1);
        $found_feature = 1;
      }

      if ( $add eq "no_path_cleanup" ) {
        Rex::Logger::debug("Enabling no_path_cleanup");
        Rex::Config->set_no_path_cleanup(1);
        $found_feature = 1;
      }

      if ( $add eq "exec_autodie" ) {
        Rex::Logger::debug("Enabling exec_autodie");
        Rex::Config->set_exec_autodie(1);
        $found_feature = 1;
      }

      if ( $add eq "no_cache" ) {
        Rex::Logger::debug("disable caching");
        Rex::Config->set_use_cache(0);
        $found_feature = 1;
      }

      if ( $add eq "verbose_run" ) {
        Rex::Logger::debug("Enabling verbose_run feature");
        Rex::Config->set_verbose_run(1);
        $found_feature = 1;
      }

      if ( $add eq "disable_taskname_warning" ) {
        Rex::Logger::debug("Enabling disable_taskname_warning feature");
        Rex::Config->set_disable_taskname_warning(1);
        $found_feature = 1;
      }

      if ( $add eq "no_task_chaining_cmdline_args" ) {
        Rex::Logger::debug("Disabling task_chaining_cmdline_args feature");
        Rex::Config->set_task_chaining_cmdline_args(0);
        $found_feature = 1;
      }

      if ( $add eq "task_chaining_cmdline_args" ) {
        Rex::Logger::debug("Enabling task_chaining_cmdline_args feature");
        Rex::Config->set_task_chaining_cmdline_args(1);
        $found_feature = 1;
      }

      if ( $add eq "write_utf8_files" ) {
        Rex::Logger::debug("Enabling write_utf8_files feature");
        Rex::Config->set_write_utf8_files(1);
        $found_feature = 1;
      }

      if ( $add eq "no_write_utf8_files" ) {
        Rex::Logger::debug("Disabling write_utf8_files feature");
        Rex::Config->set_write_utf8_files(0);
        $found_feature = 1;
      }

      if ( $found_feature == 0 ) {
        Rex::Logger::info(
          "You tried to load a feature ($add) that doesn't exists in your Rex version. Please update.",
          "warn"
        );
        exit 1;
      }

    }

  }

  if ( exists $ENV{REX_REPORT_TYPE} ) {
    Rex::Logger::debug("Enabling reporting");
    Rex::Config->set_do_reporting(1);
  }

  if ( exists $ENV{REX_SUDO} && $ENV{REX_SUDO} ) {
    Rex::global_sudo(1);
  }

  # we are always strict
  strict->import;
}

=head1 FEATURE FLAGS

Everyone knows the pain if something gets deprecated and one has to
port his old (and stable) code to a new version of a library or a
framework. There is enough work to do instead of fixing code to work
with newer versions of them.

So there is one promise new versions of Rex has to fulfill. They must
be backward compatible.

I know this might be impossible in one way or another, but to minimize
this danger there is a thing called feature flags. If there is the need
to break backward compatibility in favor of a new feature there will be
a feature flag for this change. And only if this feature flag gets
enabled in the Rexfile it will break compatibility.

So the default is always to remain compatible.

If you have a problem that occurs after an update, it is considered as
a bug. Please report this bug in our issue tracker.

Also see the L<backwards compatibility|https://metacpan.org/release/Rex/source/CONTRIBUTING.md#backwardscompatibility>
section of the CONTRIBUTING guide.

=head2 How to enable feature flags

You can enable feature flags in your Rexfile with the following code:

    use Rex -feature => ['1.4'];

or even multiple ones like this:

    use Rex -feature => [qw(1.4 exec_autodie)];

=head2 List of feature flags

=over 4

=item 1.4

Enable per-task argument parsing (L<task_chaining_cmdline_args|#task_chaining_cmdline_args>). Furthermore, all features from earlier versions are activated. Available since version 1.4.

=item no_task_chaining_cmdline_args

Disable per-task argument parsing. Available since version 1.4.

=item task_chaining_cmdline_args

Enable per-task argument parsing: C<rex --rex --args task1 --task1arg=value task2 --task2arg>
so task1 only gets C<task1arg> and task2 only gets C<task2arg>. Available since version 1.4.

=item 1.3

Activating the new template engine by default. Furthermore, all features from earlier versions are activated. Available since version 1.3.

=item no_template_ng

Disabling the new template engine. Available since version 1.3.

=item 1.0

Disabling usage of a tty. This increases compatibility for remote
execution. Furthermore, all features from earlier versions are
activated. Available since version 1.0.

=item no_autodie

Will disable autodie feature. Available since version 1.0.

=item tty

Enable pty usage for ssh connections. Available since version 1.0.

=item template_ng

Enabling the new template engine (better error reporting, etc.). Available since version 0.56.

=item 0.56

Will activate autodie feature. Furthermore, all features from earlier
versions are activated. Available since version 0.56.

=item autodie

Will enable autodie feature: die on all failed L<filesytem commands|https://metacpan.org/pod/Rex::Commands::Fs>. Available since version 1.13.1.

=item 0.55

Will activate using L<Net::OpenSSH> by default if present. Furthermore,
all features from earlier versions are activated. Available since version 0.55.

=item 0.54

Will activate checking services for existence before trying to
manipulate them, and C<set()> will overwrite already existing values
(instead of concatenating). Furthermore, all features from earlier
versions are activated. Available since version 0.54.

=item 0.53

Will activate register_cmdb_top_scope. And all things 0.51 and down
activated. Available since version 0.53.

=item register_cmdb_top_scope

Will register all cmdb top scope variables automatically in the
templates. Available since version 0.53.

=item 0.51

Will load L<Rex::Constants> and the CMDB by default. And all things 0.47
and down activated. Available since version 0.51.

=item disable_taskname_warning

Disable warning about invalid task names (they should match
C</^[a-zA-Z_][a-zA-Z0-9_]*$/>). Available since version 0.47.

=item verbose_run

Explicitly output "Successfully executed" or "Error executing" messages
for C<run()> commands. Available since version 0.47.

=item no_cache

Disable caching (like discovery results of remote OS, hardware, shell,
etc.). Available since version 0.46.

=item no_path_cleanup

Rex cleans the path before executing a command. With this feature Rex
doesn't cleanup the path. Available since version 0.44.

=item source_profile

Source C<$HOME/.profile> before running a command. Available since version 0.44.

=item source_global_profile

Source C</etc/profile> before running a command. Available since version 0.44.

=item exec_autodie

If you execute a command with C<run()> Rex will C<die()> if the command
returns a C<RETVAL != 0>. Available since version 0.44.

=item exec_and_sleep

Sometimes some commands that fork away didn't keep running. With this
flag rex will wait a few ms before exiting the shell. Available since version 0.43.

=item disable_strict_host_key_checking

Disabling strict host key checking for openssh connection mode. Available since version 0.43.

=item reporting

Enable reporting. Available since version 0.43.

=item empty_groups

Enable usage of empty groups. Available since version 0.42.

=item use_server_auth

Enable the usage of special authentication options for servers. Available since version 0.42.

=item no_tty

Disable pty usage for ssh connections. Available since version 0.41.

=item no_local_template_vars

Use global variables in templates. Available since version 0.40.

=item sudo_without_sh

Run sudo commands directly without the use of 'sh'. This might break
things. Available since version 0.40.

=item sudo_without_locales

Run sudo commands without locales. This will break things if you don't
use English locales. Available since version 0.40.

=item exit_status

This option tells Rex to return a non zero value on exit if a task
fails. Available since version 0.39.

=item 0.35

This option enables the features of 0.31 and the possibility to call
tasks as a functions without the need to use a hash reference for the
parameters. Available since version 0.35.

=item 0.31

To enable special authentication options for a server group. This will
overwrite the default authentication options for a task. Available since version 0.31.

=back

=head1 CONTRIBUTORS

Many thanks to the contributors for their work. Please see L<CONTRIBUTORS|https://metacpan.org/release/Rex/source/CONTRIBUTORS> file for a complete list.

=head1 LICENSE

Rex is a free software, licensed under:
The Apache License, Version 2.0, January 2004

=cut

1;
