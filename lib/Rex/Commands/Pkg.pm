#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Pkg - Install/Remove Software packages

=head1 DESCRIPTION

With this module you can install packages and files.

=head1 SYNOPSIS

 install file => "/etc/passwd", {
                     source => "/export/files/etc/passwd"
                 };
 
 install package => "perl";

=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Pkg;

use strict;
use warnings;

use Rex::Pkg;
use Rex::Logger;
use Rex::Template;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Hardware;
use Rex::Commands::MD5;
use Rex::Commands::Upload;
use Rex::Commands::Run;
use Rex::Config;

use Data::Dumper;
use Digest::MD5;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(install update remove installed_packages update_package_db repository package_provider_for);

=item install($type, $data, $options)

The install function can install packages (for CentOS, OpenSuSE and Debian) and files.

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
                        mode   => 644,
                    };
 };

=item installing a file and do somthing if the file was changed.

 task "prepare", "server01", sub {
    install file => "/etc/httpd/apache2.conf", {
                        source    => "/export/files/etc/httpd/apache2.conf",
                        owner     => "root",
                        group     => "root",
                        mode      => 644,
                        on_change => sub { say "File was modified!"; }
                    };
 };

=item installing a file from a template.

 task "prepare", "server01", sub {
    install file => "/etc/httpd/apache2.tpl", {
                        source    => "/export/files/etc/httpd/apache2.conf",
                        owner     => "root",
                        group     => "root",
                        mode      => 644,
                        on_change => sub { say "File was modified!"; },
                        template  => {
                                        greeting => "hello",
                                        name     => "Ben",
                                     },
                    };
 };


=back

=cut

sub install {

   my ($type, $package, $option) = @_;


   if($type eq "file") {

      Rex::Logger::debug("The install file => ... call is deprecated. Please use 'file' instead.");
      Rex::Logger::debug("This directive will be removed with (R)?ex 2.0");
      Rex::Logger::debug("See http://rexify.org/api/Rex/Commands/File.pm for more information.");
   
      my $source    = $option->{"source"};
      my $need_md5  = ($option->{"on_change"} ? 1 : 0);
      my $on_change = $option->{"on_change"} || sub {};

      my ($new_md5, $old_md5) = ("", "");
      
      if($source =~ m/\.tpl$/) {
         # das ist ein template

         my $content = eval { local(@ARGV, $/) = ($source); <>; };

         my $vars = $option->{"template"};
         my %merge1 = %{$vars || {}};
         my %merge2 = Rex::Hardware->get(qw/ All /);
         my %template_vars = (%merge1, %merge2);

         if($need_md5) {
            eval {
               $old_md5 = md5($package);
            };
         }

         my $fh = file_write($package);
         $fh->write(Rex::Config->get_template_function()->($content, \%template_vars));
         $fh->close;

         if($need_md5) {
            eval {
               $new_md5 = md5($package);
            };
         }

      }
      else {
         
         my $content = eval { local(@ARGV, $/) = ($source); <>; };

         my $local_md5 = "";
         if($option->{force}) {
            upload $source, $package;
         }
         else {
            eval {
               $old_md5 = md5($package);
               chomp $old_md5;
            };

            $local_md5 = eval { local(@ARGV) = ($source); return Digest::MD5::md5_hex(<>); };

            unless($local_md5 eq $old_md5) {
               Rex::Logger::debug("MD5 is different $local_md5 -> $old_md5 (uploading)");
               upload $source, $package;
            }
            else {
               Rex::Logger::debug("MD5 is equal. Not uploading $source -> $package");
            }

            eval {
               $new_md5 = md5($package);
            };
         }
      }

      if(exists $option->{"owner"}) {
         chown $option->{"owner"}, $package;
      }

      if(exists $option->{"group"}) {
         chgrp $option->{"group"}, $package;
      }

      if(exists $option->{"mode"}) {
         chmod $option->{"mode"}, $package;
      }

      if($need_md5) {
         unless($old_md5 && $new_md5 && $old_md5 eq $new_md5) {
            $old_md5 ||= "";
            $new_md5 ||= "";

            Rex::Logger::debug("File $package has been changed... Running on_change");
            Rex::Logger::debug("old: $old_md5");
            Rex::Logger::debug("new: $new_md5");

            &$on_change;
         }
      }
   
   }

   elsif($type eq "package") {
      
      my $pkg;
      
      $pkg = Rex::Pkg->get;

      if(!ref($package)) {
         $package = [$package];
      }

      for my $pkg_to_install (@{$package}) {
         unless($pkg->is_installed($pkg_to_install)) {
            Rex::Logger::info("Installing $pkg_to_install.");
            $pkg->install($pkg_to_install, $option);
         }
      }
     

   }
   else {
      # unknown type, be a package
      install("package", @_); 
   }

}

sub update {
   
   my ($type, $package, $option) = @_;

   if($type eq "package") {
      my $pkg;
      
      $pkg = Rex::Pkg->get;

      if(!ref($package)) {
         $package = [$package];
      }

      for my $pkg_to_install (@{$package}) {
         Rex::Logger::info("Updating $pkg_to_install.");
         $pkg->update($pkg_to_install, $option);
      }
 
   }
   else {
      update("package", @_);
   }

}

=item remove($type, $package, $options) 

This function will remove the given package from a system.

 task "cleanup", "server01", sub {
    remove package => "vim";
 };

=cut

sub remove {

   my ($type, $package, $option) = @_;


   if($type eq "package") {

      my $pkg = Rex::Pkg->get;
      unless(ref($package) eq "ARRAY") {
         $package = ["$package"];
      }

      for my $_pkg (@{$package}) {
         if($pkg->is_installed($_pkg)) {
            Rex::Logger::info("Removing $_pkg.");
            $pkg->remove($_pkg, $option);
         }
         else {
            Rex::Logger::info("$_pkg is not installed.");
         }
      }

   }

   else {
      
      Rex::Logger::info("$type not supported.");
      die("remove $type not supported");

   }

}

=item installed_packages

This function returns all installed packages and their version.

 task "get-installed", "server1", sub {
    
     for my $pkg (installed_packages()) {
        say "name     : " . $pkg->{"name"};
        say "  version: " . $pkg->{"version"};
     }
     
 };

=cut

sub installed_packages {
   my $pkg = Rex::Pkg->get;
   return $pkg->get_installed;
}

=item update_package_db

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


=item repository($action, %data)

Add or remove a repository from the package manager.

For Debian: If you have no source repository, or if you don't want to add it, just remove the I<source> parameter.

 task "add-repo", "server1", "server2", sub {
    repository "add" => "repository-name",
         url        => "http://rex.linux-files.org/debian/squeeze",
         distro     => "squeeze",
         repository => "rex",
         source     => 1;
 };

For ALT Linux: If repository is unsigned, just remove the I<sign_key> parameter.

 task "add-repo", "server1", "server2", sub {
    repository "add" => "altlinux-sisyphus",
         url        => "ftp://ftp.altlinux.org/pub/distributions/ALTLinux/Sisyphus",
         sign_key   => "alt",
         arch       => "noarch, x86_64",
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


=cut

sub repository {
   my ($action, $name, %data) = @_;
   my $pkg = Rex::Pkg->get;

   $data{"name"} = $name;

   if($action eq "add") {
      $pkg->add_repository(%data);
   }
   elsif($action eq "remove" || $action eq "delete") {
      $pkg->rm_repository(%data);
   }
}

=item package_provider_for $os => $type;

To set an other package provider as the default, use this function.

 user "root";
     
 group "db" => "db[01..10]";
 package_provider_for SunOS => "blastwave";
    
 task "prepare", group => "db", sub {
     install package => "vim";
 };

This example will install I<vim> on every db server. If the server is a Solaris (SunOS) it will use the I<blastwave> Repositories.

=cut
sub package_provider_for {
   my ($os, $provider) = @_;
   Rex::Config->set("package_provider", {$os => $provider});
}

=back

=cut

1;
