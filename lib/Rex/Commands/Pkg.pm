#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Pkg

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
use Rex::Hardware;
use Rex::Commands::MD5;
use Rex::Commands::Upload;
use Rex::Commands::Run;

use Data::Dumper;
use Digest::MD5;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(install remove);

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


   if($type eq "package") {

      my $pkg = Rex::Pkg->get;

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

   elsif($type eq "file") {
   
      my $source    = $option->{"source"};
      my $on_change = $option->{"on_change"} || sub {};

      my ($new_md5, $old_md5);
      
      if($source =~ m/\.tpl$/) {
         # das ist ein template

         my $template = Rex::Template->new;
         
         my $content = eval { local(@ARGV, $/) = ($source); <>; };

         my $vars = $option->{"template"};
         my %merge1 = %{$vars || {}};
         my %merge2 = Rex::Hardware->get(qw/ All /);
         my %template_vars = (%merge1, %merge2);

         $old_md5 = md5($package);

         my $fh = file_write($package);
         $fh->write($template->parse($content, \%template_vars));
         $fh->close;

         $new_md5 = md5($package);

      }
      else {
         
         my $content = eval { local(@ARGV, $/) = ($source); <>; };

         $old_md5 = md5($package);
         my $local_md5 = eval { local(@ARGV) = ($source); return Digest::MD5::md5_hex(<>); };

         unless($local_md5 eq $old_md5) {
            Rex::Logger::debug("MD5 is different $local_md5 -> $old_md5 (uploading)");
            upload $source, $package;
         }
         else {
            Rex::Logger::debug("MD5 is equal. Not uploading $source -> $package");
         }

         $new_md5 = md5($package);

      }

      if(exists $option->{"owner"}) {
         run "chown " . $option->{"owner"} . " $package";
      }

      if(exists $option->{"group"}) {
         run "chgrp " . $option->{"group"} . " $package";
      }

      if(exists $option->{"mode"}) {
         run "chmod " . $option->{"mode"} . " $package";
      }

      unless($old_md5 eq $new_md5) {
         Rex::Logger::debug("File $package has been changed... Running on_change");
         Rex::Logger::debug("old: $old_md5");
         Rex::Logger::debug("new: $new_md5");

         &$on_change;
      }
   
   }

   else {
      
      Rex::Logger::info("$type not supported.");
      exit 1;

   }

}

=item remove($type, $package, $options) 

This function will remove the given package from a system.

 task "cleanup", "server01", sub {
    remove "vim";
 };

=cut

sub remove {

   my ($type, $package, $option) = @_;


   if($type eq "package") {

      my $pkg = Rex::Pkg->get;

      if($pkg->is_installed($package)) {
         Rex::Logger::info("Removing $package.");
         $pkg->remove($package);
      }
      else {
         Rex::Logger::info("$package is not installed.");
      }

   }

   else {
      
      Rex::Logger::info("$type not supported.");
      exit 1;

   }

}

=back

=cut

1;
