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
   my @ret;

   if(defined $::ssh) {
      my $sftp = $::ssh->sftp;
      my $dir = $sftp->opendir($path);

      while(my $entry  = $dir->read) {
         push @ret, $entry->{'name'};
      }
   } else {
      opendir(my $dh, $path);
      while(my $entry = readdir($dh)) {
         next if ($entry =~ /^\.\.?$/);
         push @ret, $entry;
      }
      closedir($dh);
   }

   return @ret;
}

sub rm {
   my @files = @_;

   if(defined $::ssh) {
      for my $file (@files) {
         $::ssh->sftp->unlink($file);
      }
   } else {
      unlink(@files);
   }
}

sub rd {
   my @dirs = @_;

   if(defined $::ssh) {
      for my $dir (@dirs) {
         $::ssh->sftp->rmdir($dir);
      }
   } else {
      for my $dir (@dirs) {
         my @line = qx{rm -f $dir};
      }
   }
}

sub mkd {
   if(defined $::ssh) {
      $::ssh->sftp->mkdir(@_);
   } else {
      mkdir($_[0]) or die($! . " -> " . join(" ", @_));
   }
}



1;
