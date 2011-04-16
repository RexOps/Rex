#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

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

use Data::Dumper;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(install remove);

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
         else {
            Rex::Logger::info("$package already installed.");
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

         upload $source, $package;

         $new_md5 = md5($package);

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

1;
