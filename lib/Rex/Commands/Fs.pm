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
use Fcntl;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(list_files unlink rmdir mkdir stat is_file);

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

sub unlink {
   my @files = @_;

   if(defined $::ssh) {
      for my $file (@files) {
         $::ssh->sftp->unlink($file);
      }
   } else {
      CORE::unlink(@files);
   }
}

sub rmdir {
   my @dirs = @_;

   if(defined $::ssh) {
      for my $dir (@dirs) {
         $::ssh->sftp->rmdir($dir);
      }
   } else {
      for my $dir (@dirs) {
         CORE::rmdir($dir);
      }
   }
}

sub mkdir {
   if(defined $::ssh) {
      $::ssh->sftp->mkdir(@_);
   } else {
      CORE::mkdir($_[0]) or die($! . " -> " . join(" ", @_));
   }
}

sub stat {
   my %ret;
   if(defined $::ssh) {
      %ret = $::ssh->sftp->stat($_[0]);
      $ret{'mode'} = sprintf("%04o", $ret{'mode'} & 07777);
   } else {
      my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
               $atime, $mtime, $ctime, $blksize, $blocks) = CORE::stat($_[0]);
      $ret{'mode'}  = sprintf("%04o", $mode & 07777); 
      $ret{'size'}  = $size;
      $ret{'uid'}   = $uid;
      $ret{'gid'}   = $gid;
      $ret{'atime'} = $atime;
      $ret{'mtime'} = $mtime;
   }

   %ret;
}

sub is_file {
   if(defined $::ssh) {
      if( $::ssh->sftp->opendir($_[0]) ) {
         return 0;
      }

      if( ! $::ssh->sftp->open($_[0], O_RDONLY) ) {
         return 0;
      }
   } else {
      if(-d $_[0]) {
         return 0;
      }
   }

   return 1;
}


1;
