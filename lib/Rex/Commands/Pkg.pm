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

use Data::Dumper;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(install remove);

sub install {

   my ($type, $package, $option) = @_;


   if($type eq "package") {

      my $pkg = Rex::Pkg->get;

      unless($pkg->is_installed($package)) {
         Rex::Logger::info("Installing $package.");
         $pkg->install($package, $option);
      }
      else {
         Rex::Logger::info("$package already installed.");
      }

   }

   elsif($type eq "file") {
   
      my $source = $option->{"source"};
      
      if($source =~ m/\.tpl$/) {
         # das ist ein template

         my $template = Rex::Template->new;
         
         my $content = eval { local(@ARGV, $/) = ($source); <>; };

         my $vars = $option->{"template"};
         my %merge1 = %{$vars || {}};
         my %merge2 = Rex::Hardware->get(qw/ All /);
         my %template_vars = (%merge1, %merge2);

         my $fh = file_write($package);
         $fh->write($template->parse($content, \%template_vars));
         $fh->close;
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
