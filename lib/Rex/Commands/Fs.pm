#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Fs;

use strict;
use warnings;

require Exporter;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(list_files rm rd mkd);

use vars qw(%file_handles);

sub list_files {
   my $path = shift;

   if(defined $::ssh) {
      my $cmd = 'ls -1 ' . $path;
      $::ssh->send($cmd);
      my @ret = ();
      while(defined (my $line = $::ssh->read_line()) ) {
         $line =~ s/[\r\n]//gms;
         next if($line =~ m/^$/);
         push @ret, $line;
      }

      shift @ret;
      return @ret;
   } else {
      return glob($path);
   }
}

sub rm {
   my @files = @_;

   if(defined $::ssh) {
      for my $file (@files) {
         my $cmd = "rm -f $file";
         $::ssh->send($cmd);

         while(defined (my $line = $::ssh->read_line()) ) {
            $line =~ s/[\r\n]//gms;
            print "[rm] $line\n";
         }
      }
   } else {
      unlink(@files);
   }
}

sub rd {
   my @dirs = @_;

   if(defined $::ssh) {
      for my $dir (@dirs) {
         my $cmd = "rm -rf $dir";
         $::ssh->send($cmd);

         while(defined (my $line = $::ssh->read_line()) ) {
            $line =~ s/[\r\n]//gms;
            print "[rd] $line\n";
         }
      }
   } else {
      for my $dir (@dirs) {
         my @line = qx{rm -rf $dir};
         print join("\n[rd] ", @line);
      }
   }
}

sub mkd {
   if(defined $::ssh) {
      my $cmd = "mkdir " . $_[0];
      $::ssh->send($cmd);

      my @ret = ();
      while(defined (my $line = $::ssh->read_line()) ) {
         $line =~ s/[\r\n]//gms;
         next if($line =~ m/^$/);
         push @ret, $line;
      }

      return join("\n", @ret);
   } else {
      mkdir($_[0]) or die($! . " -> " . join(" ", @_));
   }
}



1;
