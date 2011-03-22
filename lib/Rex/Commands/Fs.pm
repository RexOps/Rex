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
use Rex::Helper::SSH2;
use Rex::Commands::Run;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(list_files unlink rmdir mkdir stat is_file is_dir is_readable is_writeable is_writable readlink);

use vars qw(%file_handles);

sub list_files {
   my $path = shift;
   my @ret;

   unless(is_dir($path)) {
      die("$path is not a directory.");
   }

   if(my $ssh = Rex::is_ssh()) {
      my $sftp = $ssh->sftp;
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

   if(my $ssh = Rex::is_ssh()) {
      for my $file (@files) {
         unless(is_file($file)) {
            print STDERR "unlink: $file not found\n";
            next;
         }
         $ssh->sftp->unlink($file);
      }
   } else {
      CORE::unlink(@files);
   }
}

sub rmdir {
   my @dirs = @_;

   if(is_file("/bin/rm")) {
      run "/bin/rm -rf " . join(" ", @dirs);
      unless($? == 0) {
         die("Can't delete " . join(" ", @dirs));
      }
   } else {
      die("Can't find /bin/rm");
   }
}

sub mkdir {
   if(my $ssh = Rex::is_ssh()) {
      unless($ssh->sftp->mkdir($_[0])) {
         die("Can't create directory $_[0]");
      }
   } else {
      CORE::mkdir($_[0]) or die("Can't create directory $_[0]");
   }
}

sub stat {
   my %ret;
   if(my $ssh = Rex::is_ssh()) {
      %ret = $ssh->sftp->stat($_[0]);
      
      unless(%ret) {
         die("Can't stat $_[0]");
      }

      $ret{'mode'} = sprintf("%04o", $ret{'mode'} & 07777);
   } else {
      my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
               $atime, $mtime, $ctime, $blksize, $blocks) = CORE::stat($_[0]) or die("Can't stat $_[0]");
      $ret{'mode'}  = sprintf("%04o", $mode & 07777); 
      $ret{'size'}  = $size;
      $ret{'uid'}   = $uid;
      $ret{'gid'}   = $gid;
      $ret{'atime'} = $atime;
      $ret{'mtime'} = $mtime;
   }

   return %ret;
}

sub is_file {
   if(my $ssh = Rex::is_ssh()) {
      if( $ssh->sftp->opendir($_[0]) ) {
         return 0;
      }

      if( ! $ssh->sftp->open($_[0], O_RDONLY) ) {
         return 0;
      }
   } else {
      if(! -f $_[0]) {
         return 0;
      }
   }

   return 1;
}

sub is_dir {
   if(my $ssh = Rex::is_ssh()) {
      if( ! $ssh->sftp->opendir($_[0]) ) {
         return 0;
      }
   } else {
      if( ! -d $_[0]) {
         return 0;
      }
   }

   return 1;
}

sub is_readable {
   if(my $ssh = Rex::is_ssh()) {
      my $out = net_ssh2_exec($ssh, "/usr/bin/perl -le 'if(-r \"$_[0]\") { print \"1\"; }'");
      chomp $out;
      if($out) {
         return 1;
      }
   } else {
      if(-r $_[0]) {
         return 1;
      }
   }

   return 0;
}

sub is_writable {
   if(my $ssh = Rex::is_ssh()) {
      my $out = net_ssh2_exec($ssh, "/usr/bin/perl -le 'if(-w \"$_[0]\") { print \"1\"; }'");
      chomp $out;
      if($out) {
         return 1;
      }
   } else {
      if(-w $_[0]) {
         return 1;
      }
   }

   return 0;
}

sub is_writeable {
   is_writable(@_);
}

sub readlink {
   my $link;
   if(my $ssh = Rex::is_ssh()) {
      $link = $ssh->sftp->readlink($_[0]);
   } else {
      $link = CORE::readlink($_[0]);
   }

   unless($link) {
      die("readlink: $_[0] is not a link.");
   }
}


1;
