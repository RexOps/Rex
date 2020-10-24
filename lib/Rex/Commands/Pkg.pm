#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Pkg - Install/Remove Software packages

=head1 DESCRIPTION

With this module you can install packages and files.

=head1 SYNOPSIS

 pkg "somepkg",
   ensure => "present";
 pkg "somepkg",
   ensure => "latest",
   on_change => sub {
     say "package was updated.";
     service someservice => "restart";
   };
 pkg "somepkg",
   ensure => "absent";

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Pkg;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Pkg;
use Rex::Logger;
use Rex::Template;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Commands::MD5;
use Rex::Commands::Upload;
use Rex::Config;
use Rex::Commands;
use Rex::Hook;

use Data::Dumper;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT =
  qw(install update remove update_system installed_packages is_installed update_package_db repository package_provider_for pkg);

=head2 pkg($package, %options)

Since: 0.45

Use this resource to install or update a package. This resource will generate reports.

 pkg "httpd",
   ensure    => "latest",    # ensure that the newest version is installed (auto-update)
   on_change => sub { say "package was installed/updated"; };

 pkg "httpd",
   ensure => "absent";    # remove the package

 pkg "httpd",
   ensure => "present";   # ensure that some version is installed (no auto-update)

 pkg "httpd",
   ensure => "2.4.6";    # ensure that version 2.4.6 is installed

 pkg "apache-server",    # with a custom resource name
   package => "httpd",
   ensure  => "present";

=cut

sub pkg {
  my ( $package, %option ) = @_;

  if ( exists $option{package} && ref $option{package} eq "ARRAY" ) {
    die "The `package´ option can't be an array.";
  }

  my $res_name = $package;

  if ( exists $option{package} ) {
    $package = $option{package};
  }

  $option{ensure} ||= "present";

  my @package_list = ref $package eq "ARRAY" ? @{$package} : ($package);

  foreach my $candidate ( sort @package_list ) {
    Rex::get_current_connection()->{reporter}->report_resource_start(
      type => "pkg",
      name => ( ref $res_name eq "ARRAY" ? $candidate : $res_name )
    );
  }

  my $pkg           = Rex::Pkg->get;
  my @old_installed = $pkg->get_installed;

  if ( $option{ensure} eq "latest" ) {
    &update( package => $package, \%option );
  }
  elsif ( $option{ensure} =~ m/^(present|installed)$/ ) {
    &install( package => $package, \%option );
  }
  elsif ( $option{ensure} eq "absent" ) {
    &remove( package => $package );
  }
  elsif ( $option{ensure} =~ m/^\d/ ) {

    # looks like a version
    &install( package => $package, { version => $option{ensure} } );
  }
  else {
    die("Unknown ensure parameter: $option{ensure}.");
  }

  my @new_installed = $pkg->get_installed;
  my @modifications =
    $pkg->diff_package_list( \@old_installed, \@new_installed );

  if ( exists $option{on_change}
    && ref $option{on_change} eq "CODE"
    && scalar @modifications > 0 )
  {
    $option{on_change}->( $package, %option );
  }

  foreach my $candidate ( reverse sort @package_list ) {

    my %report_args = ( changed => 0 );

    if ( my ($change) = grep { $candidate eq $_->{name} } @modifications ) {
      $report_args{changed} = 1;

      my ($old_package) = grep { $_->{name} eq $change->{name} } @old_installed;
      my ($new_package) = grep { $_->{name} eq $change->{name} } @new_installed;

      if ( $change->{action} eq "updated" ) {
        $report_args{message} =
          "Package $change->{name} updated $old_package->{version} -> $new_package->{version}";
      }
      elsif ( $change->{action} eq "installed" ) {
        $report_args{message} =
          "Package $change->{name} installed in version $new_package->{version}";
      }
      elsif ( $change->{action} eq "removed" ) {
        $report_args{message} = "Package $change->{name} removed.";
      }
    }

    Rex::get_current_connection()->{reporter}->report(%report_args);

    Rex::get_current_connection()->{reporter}->report_resource_end(
      type => "pkg",
      name => ( ref $res_name eq "ARRAY" ? $candidate : $res_name )
    );
  }
}

=head2 install($type, $data, $options)

The install function can install packages (for CentOS, OpenSuSE and Debian) and files.

If you need reports, please use the pkg() resource.

=over 8

=item installing a package (This is only supported on CentOS, OpenSuSE and Debian systems.)

 task "prepare", "server01", sub {
   install package => "perl";

   # or if you have to install more packages.
   install package => [
                  "perl",
                  "ntp",
                  "dbus",
                  "hal",
                  "sudo",
                  "vim",
                ];
 };

=item installing a file

This is deprecated since 0.9. Please use L<File> I<file> instead.

 task "prepare", "server01", sub {
   install file => "/etc/passwd", {
                source => "/export/files/etc/passwd",
                owner  => "root",
                group  => "root",
                mode  => 644,
              };
 };

=item installing a file and do something if the file was changed.

 task "prepare", "server01", sub {
   install file => "/etc/httpd/apache2.conf", {
                source   => "/export/files/etc/httpd/apache2.conf",
                owner    => "root",
                group    => "root",
                mode    => 644,
                on_change => sub { say "File was modified!"; }
              };
 };

=item installing a file from a template.

 task "prepare", "server01", sub {
   install file => "/etc/httpd/apache2.tpl", {
                source   => "/export/files/etc/httpd/apache2.conf",
                owner    => "root",
                group    => "root",
                mode    => 644,
                on_change => sub { say "File was modified!"; },
                template  => {
                           greeting => "hello",
                           name    => "Ben",
                         },
              };
 };


=back

This function supports the following L<hooks|Rex::Hook>:

=over 4

=item before

This gets executed before anything is done. All original parameters are passed to it.

The return value of this hook overwrites the original parameters of the function-call.

=item before_change

This gets executed right before the new package is installed. All original parameters are passed to it.

This hook is only available for package installations. If you need file hooks, you have to use the L<file()|Rex::Commands::File#file> function.

=item after_change

This gets executed right after the new package was installed. All original parameters, and the fact of change (C<{ changed => TRUE|FALSE }>) are passed to it.

This hook is only available for package installations. If you need file hooks, you have to use the L<file()|Rex::Commands::File#file> function.

=item after
 
This gets executed right before the C<install()> function returns. All original parameters, and any returned results are passed to it.

=back

=cut

sub install {

  if ( !@_ ) {
    return "install";
  }

  #### check and run before hook
  my @orig_params = @_;
  eval {
    my @new_args = Rex::Hook::run_hook( install => "before", @_ );
    if (@new_args) {
      @_ = @new_args;
    }
    1;
  } or do {
    die("Before-Hook failed. Canceling install() action: $@");
  };
  ##############################

  my $type    = shift;
  my $package = shift;
  my $option;
  my $__ret;

  if ( $type eq "file" ) {

    if ( ref( $_[0] ) eq "HASH" ) {
      $option = shift;
    }
    else {
      $option = {@_};
    }

    Rex::Logger::debug(
      "The install file => ... call is deprecated. Please use 'file' instead.");
    Rex::Logger::debug("This directive will be removed with (R)?ex 2.0");
    Rex::Logger::debug(
      "See http://rexify.org/api/Rex/Commands/File.pm for more information.");

    my $source    = $option->{"source"};
    my $need_md5  = ( $option->{"on_change"} ? 1 : 0 );
    my $on_change = $option->{"on_change"} || sub { };
    my $__ret;

    my ( $new_md5, $old_md5 ) = ( "", "" );

    if ( $source =~ m/\.tpl$/ ) {

      # das ist ein template

      my $content = eval { local ( @ARGV, $/ ) = ($source); <>; };

      my $vars          = $option->{"template"};
      my %merge1        = %{ $vars || {} };
      my %merge2        = Rex::Hardware->get(qw/ All /);
      my %template_vars = ( %merge1, %merge2 );

      if ($need_md5) {
        eval { $old_md5 = md5($package); };
      }

      my $fh = file_write($package);
      $fh->write(
        Rex::Config->get_template_function()->( $content, \%template_vars ) );
      $fh->close;

      if ($need_md5) {
        eval { $new_md5 = md5($package); };
      }

    }
    else {

      my $source  = Rex::Helper::Path::get_file_path( $source, caller() );
      my $content = eval { local ( @ARGV, $/ ) = ($source); <>; };

      my $local_md5 = "";
      if ( $option->{force} ) {
        upload $source, $package;
      }
      else {
        eval {
          $old_md5 = md5($package);
          chomp $old_md5;
        };

        LOCAL {
          $local_md5 = md5($source);
        };

        unless ( $local_md5 eq $old_md5 ) {
          Rex::Logger::debug(
            "MD5 is different $local_md5 -> $old_md5 (uploading)");
          upload $source, $package;
        }
        else {
          Rex::Logger::debug("MD5 is equal. Not uploading $source -> $package");
        }

        eval { $new_md5 = md5($package); };
      }
    }

    if ( exists $option->{"owner"} ) {
      chown $option->{"owner"}, $package;
    }

    if ( exists $option->{"group"} ) {
      chgrp $option->{"group"}, $package;
    }

    if ( exists $option->{"mode"} ) {
      chmod $option->{"mode"}, $package;
    }

    if ($need_md5) {
      unless ( $old_md5 && $new_md5 && $old_md5 eq $new_md5 ) {
        $old_md5 ||= "";
        $new_md5 ||= "";

        Rex::Logger::debug(
          "File $package has been changed... Running on_change");
        Rex::Logger::debug("old: $old_md5");
        Rex::Logger::debug("new: $new_md5");

        &$on_change;
      }
    }

  }

  elsif ( $type eq "package" ) {

    if ( ref( $_[0] ) eq "HASH" ) {
      $option = shift;
    }
    elsif ( $_[0] ) {
      $option = {@_};
    }

    my $pkg;

    $pkg = Rex::Pkg->get;

    if ( !ref($package) ) {
      $package = [$package];
    }

    my $changed = 0;

    # if we're being asked to install a single package
    if ( @{$package} == 1 ) {
      my $pkg_to_install = shift @{$package};
      unless ( $pkg->is_installed( $pkg_to_install, $option ) ) {
        Rex::Logger::info("Installing $pkg_to_install.");

        #### check and run before_change hook
        Rex::Hook::run_hook( install => "before_change", @orig_params );
        ##############################

        $pkg->install( $pkg_to_install, $option );
        $changed = 1;

        #### check and run after_change hook
        Rex::Hook::run_hook(
          install => "after_change",
          @orig_params, { changed => $changed }
        );
        ##############################
      }
    }
    else {
      my @pkgCandidates;
      for my $pkg_to_install ( @{$package} ) {
        unless ( $pkg->is_installed( $pkg_to_install, $option ) ) {
          push @pkgCandidates, $pkg_to_install;
        }
      }

      if (@pkgCandidates) {
        Rex::Logger::info("Installing @pkgCandidates");
        $pkg->bulk_install( \@pkgCandidates, $option ); # here, i think $option is useless in its current form.
        $changed = 1;
      }
    }

    if ( Rex::Config->get_do_reporting ) {
      $__ret = { changed => $changed };
    }

  }
  else {
    # unknown type, be a package
    install( "package", $type, $package, @_ );

    if ( Rex::Config->get_do_reporting ) {
      $__ret = { skip => 1 };
    }
  }

  #### check and run after hook
  Rex::Hook::run_hook( install => "after", @orig_params, $__ret );
  ##############################

  return $__ret;

}

sub update {

  my ( $type, $package, $option ) = @_;

  if ( $type eq "package" ) {
    my $pkg;

    $pkg = Rex::Pkg->get;

    if ( !ref($package) ) {
      $package = [$package];
    }

    for my $pkg_to_install ( @{$package} ) {
      Rex::Logger::info("Updating $pkg_to_install.");
      $pkg->update( $pkg_to_install, $option );
    }

  }
  else {
    update( "package", @_ );
  }

}

=head2 remove($type, $package, $options)

This function will remove the given package from a system.

 task "cleanup", "server01", sub {
   remove package => "vim";
 };

=cut

sub remove {

  my ( $type, $package, $option ) = @_;

  if ( $type eq "package" ) {

    my $pkg = Rex::Pkg->get;
    unless ( ref($package) eq "ARRAY" ) {
      $package = ["$package"];
    }

    for my $_pkg ( @{$package} ) {
      if ( $pkg->is_installed($_pkg) ) {
        Rex::Logger::info("Removing $_pkg.");
        $pkg->remove( $_pkg, $option );
        $pkg->purge( $_pkg, $option );
      }
      else {
        Rex::Logger::info("$_pkg is not installed.");
      }
    }

  }

  else {

    #Rex::Logger::info("$type not supported.");
    #die("remove $type not supported");
    # no type given, assume package
    remove( "package", $type, $option );

  }

}

=head2 update_system

This function does a complete system update.

For example I<apt-get upgrade> or I<yum update>.

 task "update-system", "server1", sub {
   update_system;
 };

If you want to get the packages that where updated, you can use the I<on_change> hook.

 task "update-system", "server1", sub {
   update_system
     on_change => sub {
       my (@modified_packages) = @_;
       for my $pkg (@modified_packages) {
         say "Name: $pkg->{name}";
         say "Version: $pkg->{version}";
         say "Action: $pkg->{action}";   # some of updated, installed or removed
       }
     };
 };

Options for I<update_system>

=over 4

=item update_metadata

Set to I<TRUE> if the package metadata should be updated. Since 1.5 default to I<FALSE> if possible. Before 1.5 it depends on the package manager.

=item update_package

Set to I<TRUE> if you want to update the packages. Default is I<TRUE>.

=item dist_upgrade

Set to I<TRUE> if you want to run a dist-upgrade if your distribution supports it. Default is I<FALSE>.

=back

=cut

sub update_system {
  my $pkg = Rex::Pkg->get;
  my (%option) = @_;

  # safe the currently installed packages, so that we can compare
  # the package db for changes
  my @old_installed = $pkg->get_installed;

  eval { $pkg->update_system(%option); };
  Rex::Logger::info( "An error occurred for update_system: $@", "warn" ) if $@;

  my @new_installed = $pkg->get_installed;

  my @modifications =
    $pkg->diff_package_list( \@old_installed, \@new_installed );

  if ( scalar @modifications > 0 ) {

    # there where some changes in the package database
    if ( exists $option{on_change} && ref $option{on_change} eq "CODE" ) {

      # run the on_change hook
      $option{on_change}->(@modifications);
    }
  }
}

=head2 installed_packages

This function returns all installed packages and their version.

 task "get-installed", "server1", sub {

    for my $pkg (installed_packages()) {
      say "name    : " . $pkg->{"name"};
      say "  version: " . $pkg->{"version"};
    }

 };

=cut

sub installed_packages {
  my $pkg = Rex::Pkg->get;
  return $pkg->get_installed;
}

=head2 is_installed

This function tests if $package is installed. Returns 1 if true. 0 if false.

 task "isinstalled", "server01", sub {
   if( is_installed("rex") ) {
     say "Rex is installed";
   }
   else {
     say "Rex is not installed";
   }
 };

=cut

sub is_installed {
  my $package = shift;
  my $pkg     = Rex::Pkg->get;
  return $pkg->is_installed($package);
}

=head2 update_package_db

This function updates the local package database. For example, on CentOS it will execute I<yum makecache>.

 task "update-pkg-db", "server1", "server2", sub {
   update_package_db;
   install package => "apache2";
 };

=cut

sub update_package_db {
  my $pkg = Rex::Pkg->get;
  $pkg->update_pkg_db();
}

=head2 repository($action, %data)

Add or remove a repository from the package manager.

For Debian: If you have no source repository, or if you don't want to add it, just remove the I<source> parameter.

 task "add-repo", "server1", "server2", sub {
   repository "add" => "repository-name",
      url      => "http://rex.linux-files.org/debian/squeeze",
      key_url  => "http://rex.linux-files.org/DPKG-GPG-KEY-REXIFY-REPO"
      distro    => "squeeze",
      repository => "rex",
      source    => 1;
 };

To specify a key from a file use key_file => '/tmp/mykeyfile'.

To use a keyserver use key_server and key_id.

For ALT Linux: If repository is unsigned, just remove the I<sign_key> parameter.

 task "add-repo", "server1", "server2", sub {
   repository "add" => "altlinux-sisyphus",
      url      => "ftp://ftp.altlinux.org/pub/distributions/ALTLinux/Sisyphus",
      sign_key  => "alt",
      arch     => "noarch, x86_64",
      repository => "classic";
 };

For CentOS, Mageia and SuSE only the name and the url are needed.

 task "add-repo", "server1", "server2", sub {
   repository add => "repository-name",
      url => 'http://rex.linux-files.org/CentOS/$releasever/rex/$basearch/';

 };

To remove a repository just delete it with its name.

 task "rm-repo", "server1", sub {
   repository remove => "repository-name";
 };

You can also use one call to repository to add repositories on multiple platforms:

 task "add-repo", "server1", "server2", sub {
  repository add => myrepo => {
    Ubuntu => {
      url => "http://foo.bar/repo",
      distro => "precise",
      repository => "foo",
    },
    Debian => {
      url => "http://foo.bar/repo",
      distro => "squeeze",
      repository => "foo",
    },
    CentOS => {
      url => "http://foo.bar/repo",
    },
  };
 };


=cut

sub repository {
  my ( $action, $name, @__data ) = @_;

  my %data;

  if ( ref( $__data[0] ) ) {
    if ( !exists $__data[0]->{ get_operating_system() } ) {
      if ( exists $__data[0]->{default} ) {
        %data = $__data[0]->{default};
      }
      else {
        die(
          "No repository information found for os: " . get_operating_system() );
      }
    }
    else {
      %data = %{ $__data[0]->{ get_operating_system() } };
    }
  }
  else {
    %data = @__data;
  }

  my $pkg = Rex::Pkg->get;

  $data{"name"} = $name;

  my $ret;
  if ( $action eq "add" ) {
    $ret = $pkg->add_repository(%data);
  }
  elsif ( $action eq "remove" || $action eq "delete" ) {
    $ret = $pkg->rm_repository($name);
  }

  if ( exists $data{after} ) {
    $data{after}->();
  }

  return $ret;
}

=head2 package_provider_for $os => $type;

To set another package provider as the default, use this function.

 user "root";

 group "db" => "db[01..10]";
 package_provider_for SunOS => "blastwave";

 task "prepare", group => "db", sub {
    install package => "vim";
 };

This example will install I<vim> on every db server. If the server is a Solaris (SunOS) it will use the I<blastwave> Repositories.

=cut

sub package_provider_for {
  my ( $os, $provider ) = @_;
  Rex::Config->set( "package_provider", { $os => $provider } );
}

1;
