#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Fs::Local;
   
use strict;
use warnings;

use Rex::Interface::Fs::Base;
use base qw(Rex::Interface::Fs::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub upload {
   my ($self, $source, $target) = @_;
   $self->cp($source, $target);
}

sub download {
   my ($self, $source, $target) = @_;
   $self->cp($source, $target);
}

sub ls {
   my ($self, $path) = @_;

   my @ret;

   eval {
      opendir(my $dh, $path) or die("$path is not a directory");
      while(my $entry = readdir($dh)) {
         next if ($entry =~ /^\.\.?$/);
         push @ret, $entry;
      }
      closedir($dh);
   };

   # failed open directory, return undef
   if($@) { return; }

   # return directory content
   return @ret;
}

sub rmdir {
   my ($self, @dirs) = @_;

   Rex::Logger::debug("Removing directories: " . join(", ", @dirs));
   my $exec = Rex::Interface::Exec->create;
   if($^O =~ m/^MSWin/) {
      $exec->exec("rd /Q /S " . join(" ", @dirs));
   }
   else {
      $exec->exec("/bin/rm -rf " . join(" ", @dirs));
   }

   if($? == 0) { return 1; }
}


sub is_dir {
   my ($self, $path) = @_;
   if(-d $path) { return 1; }
}

sub is_file {
   my ($self, $file) = @_;
   if(-f $file) { return 1; }
}

sub unlink {
   my ($self, @files) = @_;
   CORE::unlink(@files);
}

sub mkdir {
   my ($self, $dir) = @_;
   CORE::mkdir($dir);
}

sub stat {
   my ($self, $file) = @_;

   if(my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
               $atime, $mtime, $ctime, $blksize, $blocks) = CORE::stat($file)) {

         my %ret;

         $ret{'mode'}  = sprintf("%04o", $mode & 07777); 
         $ret{'size'}  = $size;
         $ret{'uid'}   = $uid;
         $ret{'gid'}   = $gid;
         $ret{'atime'} = $atime;
         $ret{'mtime'} = $mtime;

         return %ret;
   }

}

sub is_readable {
   my ($self, $file) = @_;
   if(-r $file) { return 1; }
}

sub is_writable {
   my ($self, $file) = @_;
   if(-w $file) { return 1; }
}

sub readlink {
   my ($self, $file) = @_;
   return CORE::readlink($file);
}

sub rename {
   my ($self, $old, $new) = @_;
   return CORE::rename($old, $new);
}

sub glob {
   my ($self, $glob) = @_;
   return CORE::glob($glob);
}

1;
