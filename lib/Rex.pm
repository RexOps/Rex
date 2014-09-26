#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=encoding UTF-8

=head1 NAME

Rex - Remote Execution

=head1 DESCRIPTION

(R)?ex is a small script to ease the execution of remote commands. You can write small tasks in a file named I<Rexfile>.

You can find examples and howtos on L<http://rexify.org/>

=head1 GETTING HELP

=over 4

=item * Web Site: L<http://rexify.org/>

=item * IRC: irc.freenode.net #rex

=item * Bug Tracker: L<https://github.com/RexOps/Rex/issues>

=item * Twitter: L<http://twitter.com/jfried83>

=back

=head1 SYNOPSIS

 use strict;
 use warnings;

 user "root";
 password "ch4ngem3";

 desc "Show Unix version";
 task "uname", sub {
    say run "uname -a";
 };

 bash# rex -H "server[01..10]" uname

See L<Rex::Commands> for a list of all commands you can use.

=head1 CLASS METHODS

=over 4

=cut

package Rex;

use strict;
use warnings;

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

our ( @EXPORT, $VERSION, @CONNECTION_STACK, $GLOBAL_SUDO, $MODULE_PATHS,
  $WITH_EXIT_STATUS );

$WITH_EXIT_STATUS = 1;    # since 0.50 activated by default

my $cur_dir;

BEGIN {

  sub _home_dir {
    if ( $^O =~ m/^MSWin/ ) {
      return $ENV{'USERPROFILE'};
    }

    return $ENV{'HOME'} || "";
  }

  $cur_dir = getcwd;

  unshift(
    @INC,
    sub {
      my $mod_to_load = $_[1];
      return search_module_path( $mod_to_load, 1 );
    }
  );

  if ( -d "$cur_dir/lib" ) {
    push( @INC, "$cur_dir/lib" );
    push( @INC, "$cur_dir/lib/perl/lib/perl5" );
    if ( $^O =~ m/^MSWin/ ) {
      my ($special_win_path) = grep { m/\/MSWin32\-/ } @INC;
      my $mswin32_path = basename $special_win_path;
      push( @INC, "$cur_dir/lib/perl/lib/perl5/$mswin32_path" );
    }
  }

  my $home_dir = _home_dir();
  if ( -d "$home_dir/.rex/recipes" ) {
    push( @INC, "$home_dir/.rex/recipes" );
  }

  push(
    @INC,
    sub {
      my $mod_to_load = $_[1];
      return search_module_path( $mod_to_load, 0 );
    }
  );

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
    if ( -f $file ) {
      my ($path) = ( $file =~ m/^(.*)\/.+?$/ );
      if ( $path !~ m/\// ) {
        $path = $cur_dir . "/$path";
      }

      # module found, register path
      $MODULE_PATHS->{$mod_to_load} = { path => $path };
      my $mod_package_name = $mod_to_load;
      $mod_package_name =~ s/\//::/g;
      $MODULE_PATHS->{$mod_package_name} = { path => $path };

      if ($pre) {
        return;
      }

      open( my $fh, $file );
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

=item get_current_connection

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

=item is_ssh

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

=item is_local

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

=item is_sudo

Returns 1 if the current operation is executed within sudo.

=cut

sub is_sudo {
  if ($GLOBAL_SUDO) { return 1; }

  if ( exists $CONNECTION_STACK[-1]->{server}->{auth}->{sudo}
    && $CONNECTION_STACK[-1]->{server}->{auth}->{sudo} == 1 )
  {
    return 1;
  }

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

=item get_sftp

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

=item connect

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
  my $port        = $param->{port} || 22;
  my $timeout     = $param->{timeout} || 5;
  my $user        = $param->{"user"};
  my $pass        = $param->{"password"};
  my $cached_conn = $param->{"cached_connection"};

  if ( !$cached_conn ) {
    my $conn = Rex::Interface::Connection->create("SSH");

    $conn->connect(
      user     => $user,
      password => $pass,
      server   => $server,
      port     => $port,
      timeout  => $timeout,
      %{$param},
    );

    unless ( $conn->is_connected ) {
      die("Connetion error or refused.");
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

sub import {
  my ( $class, $what, $addition1 ) = @_;

  $what ||= "";

  my ( $register_to, $file, $line ) = caller;

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

  }

  if ( $what eq "-feature" || $what eq "feature" ) {

    if ( !ref($addition1) ) {
      $addition1 = [$addition1];
    }

    for my $add ( @{$addition1} ) {

      my $found_feature = 0;

      if ( $add =~ m/^(\d+\.\d+)$/ ) {
        my $vers = $1;
        my ( $major, $minor, $patch ) = split( /\./, $VERSION );
        my ( $c_major, $c_minor ) = split( /\./, $vers );

        if ( ( $c_major > $major )
          || ( $c_major >= $major && $c_minor > $minor ) )
        {
          Rex::Logger::info(
            "This Rexfile tries to enable features that are not supported with your version. Please update.",
            "warn"
          );
          exit 1;
        }
      }

      # remove default task auth
      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.31 ) {
        Rex::Logger::debug("activating featureset >= 0.31");
        Rex::TaskList->create()->set_default_auth(0);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.35 ) {
        Rex::Logger::debug("activating featureset >= 0.35");
        $Rex::Commands::REGISTER_SUB_HASH_PARAMETER = 1;
        $found_feature                              = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.40 ) {
        Rex::Logger::debug("activating featureset >= 0.40");
        $Rex::Template::BE_LOCAL = 1;
        $Rex::WITH_EXIT_STATUS   = 1;
        $found_feature           = 1;
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

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.53 ) {
        Rex::Logger::debug("Registering CMDB as template variables.");
        Rex::Config->set_register_cmdb_template(1);
        $found_feature = 1;
      }

      if ( $add =~ m/^\d+\.\d+$/ && $add >= 0.54 ) {
        Rex::Logger::debug("Add service check.");
        Rex::Config->set_check_service_exists(1);
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

=back

=head1 CONTRIBUTORS

Many thanks to the contributors for their work (alphabetical order).

=over 4

=item alex1line

=item Alexandr Ciornii

=item Anders Ossowicki

=item Andrej Zverev

=item bollwarm

=item Boris Däppen

=item Cameron Daniel

=item Chris Steigmeier

=item complefor

=item Cuong Manh Le

=item Daniel Baeurer

=item David Golovan

=item Dominik Danter

=item Dominik Schulz

=item eduardoj

=item Erik Huelsmann

=item fanyeren

=item Ferenc Erki

=item Fran Rodriguez

=item Franky Van Liedekerke

=item Gilles Gaudin, for writing a french howto

=item Hiroaki Nakamura

=item Ilya Evseev

=item Jean Charles Passard

=item Jean-Marie Renouard

=item Jeen Lee

=item Jens Berthold

=item Jonathan Delgado

=item Jon Gentle

=item Joris

=item Jose Luis Martinez

=item Kasim Tuman

=item Keedi Kim

=item Laird Liu

=item Mario Domgoergen

=item Nathan Abu

=item Naveed Massjouni

=item Nicolas Leclercq

=item Niklas Larsson

=item Nikolay Fetisov

=item Nils Domrose

=item Peter H. Ezetta

=item Piotr Karbowski

=item Rao Chenlin (Chenryn)

=item RenatoCRON

=item Renee Bäcker

=item Samuele Tognini

=item Sascha Guenther

=item Simon Bertrang

=item Stephane Benoit

=item Sven Dowideit

=item Tianon Gravi

=item Tokuhiro Matsuno

=item Tomohiro Hosaka

=back

=cut

1;
