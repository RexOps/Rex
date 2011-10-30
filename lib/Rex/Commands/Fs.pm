#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Fs - Filesystem commands

=head1 DESCRIPTION

With this module you can do file system tasks like creating a directory, removing files, move files, and more.

=head1 SYNOPSIS

 my @files = list_files "/etc";

 unlink("/tmp/file");

 rmdir("/tmp");
 mkdir("/tmp");

 my %stat = stat("/etc/passwd");

 my $link = readlink("/path/to/a/link");
 symlink("/source", "/dest");

 rename("oldname", "newname");

 chdir("/tmp");

 is_file("/etc/passwd");
 is_dir("/etc");
 is_writeable("/tmp");
 is_writable("/tmp");

 chmod 755, "/tmp";
 chown "user", "/tmp";
 chgrp "group", "/tmp";


=head1 EXPORTED FUNCTIONS

=over 4

=cut



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

@EXPORT = qw(list_files ls
            unlink rm rmdir mkdir stat readlink symlink ln rename mv chdir cd cp
            chown chgrp chmod
            is_file is_dir is_readable is_writeable is_writable
            df du
            mount umount
            glob);

use vars qw(%file_handles);

=item list_files("/path");

This function list all entries (files, directories, ...) in a given directory and returns a array.

 task "ls-etc", "server01", sub {
    my @tmp_files = grep { /\.tmp$/ } list_files("/etc");
 };

=cut

sub list_files {
   my $path = shift;
   my @ret;

   unless(is_dir($path)) {
      Rex::Logger::debug("$path is not a directory.");
      die("$path is not a directory.");
   }

   Rex::Logger::debug("Reading directory contents.");
   if(my $sftp = Rex::get_sftp()) {
      my $dir = $sftp->opendir($path);
      unless($dir) {
         die("Can't read $path");
      }

      while(my $entry  = $dir->read) {
         push @ret, $entry->{'name'};
      }
   } else {
      opendir(my $dh, $path);
      unless($dh) {
         die("Can't read $path");
      }
      while(my $entry = readdir($dh)) {
         next if ($entry =~ /^\.\.?$/);
         push @ret, $entry;
      }
      closedir($dh);
   }

   return @ret;
}

=item ls($path)

Just an alias for I<list_files>

=cut

sub ls {
   return list_files(@_);
}

=item symlink($from, $to)

This function will create a symlink from $from to $to.

 task "symlink", "server01", sub {
    symlink("/var/www/versions/1.0.0", "/var/www/html");
 };

=cut

sub symlink {
   my ($from, $to) = @_;

   Rex::Logger::debug("Symlinking files: $to -> $from");

   run "ln -snf $from $to";

   if($? != 0) {
      die("Can't link $from -> $to");
   }

}

=item ln($from, $to)

ln is an alias for I<symlink>

=cut

sub ln {
   &symlink(@_);
}

=item unlink($file)

This function will remove the given file.

 task "unlink", "server01", sub {
    unlink("/tmp/testfile");
 };

=cut

sub unlink {
   my @files = @_;

   Rex::Logger::debug("Unlinking files: " . join(", ", @files));

   if(my $sftp = Rex::get_sftp()) {
      for my $file (@files) {
         unless(is_file($file)) {
            Rex::Logger::info("unlink: $file not found");
            next;
         }
         $sftp->unlink($file);
      }
   } else {
      CORE::unlink(@files);
   }
}

=item rm($file)

This is an alias for unlink.

=cut

sub rm {
   &unlink(@_);
}

=item rmdir($dir)

This function will remove the given directory.

 task "rmdir", "server01", sub {
    rmdir("/tmp");
 };

=cut

sub rmdir {
   my @dirs = @_;

   Rex::Logger::debug("Removing directories: " . join(", ", @dirs));

   if(is_file("/bin/rm")) {
      run "/bin/rm -rf " . join(" ", @dirs);
      unless($? == 0) {
         Rex::Logger::debug("Can't delete " . join(", ", @dirs));
         die("Can't delete " . join(", ", @dirs));
      }
   } else {
      Rex::Logger::debug("/bin/rm not found.");
      die("Can't find /bin/rm");
   }
}

=item mkdir($newdir)

This function will create a new directory.

 task "mkdir", "server01", sub {
    mkdir "/tmp";

    mkdir "/tmp",
      owner => "root",
      group => "root",
      mode => 1777;
 };

=cut

sub mkdir {
   Rex::Logger::debug("Creating directory $_[0]");
   my $dir = shift;
   my $options = { @_ };

   my $mode  = $options->{"mode"}  || 755;
   my $owner = $options->{"owner"} || "";
   my $group = $options->{"group"} || "";
   my $not_recursive = $options->{"not_recursive"} || 0;

   if($not_recursive) {
      if(my $sftp = Rex::get_sftp()) {
         unless($sftp->mkdir($dir)) {
            Rex::Logger::debug("Can't create directory $dir");
            die("Can't create directory $dir");
         }
      }
      else {
         unless(CORE::mkdir($dir)) {
            Rex::Logger::debug("Can't create directory $dir");
            die("Can't create directory $dir");
         }

         &chown($owner, $dir) if $owner;
         &chgrp($group, $dir) if $group;
         &chmod($mode, $dir)  if $owner;
      }
   }

   my @splitted_dir = map { $_="/$_"; } split(/\//, $dir);
   unless($splitted_dir[0] eq "/") {
      $splitted_dir[0] = "." . $splitted_dir[0];
   }
   else {
      shift @splitted_dir;
   }

   my $str_part="";
   for my $part (@splitted_dir) {
      $str_part .= "$part";

      if(! is_dir($str_part) && ! is_file($str_part)) {
         if(my $sftp = Rex::get_sftp()) {
            unless($sftp->mkdir($str_part)) {
               Rex::Logger::debug("Can't create directory $dir");
               die("Can't create directory $dir");
            }
         }
         else {
            unless(CORE::mkdir($str_part)) {
               Rex::Logger::debug("Can't create directory $dir");
               die("Can't create directory $dir");
            }
         }

         &chown($owner, $str_part) if $owner;
         &chgrp($group, $str_part) if $group;
         &chmod($mode, $str_part)  if $owner;

      }
   }
}

=item chown($owner, $file)

Change the owner of a file or a directory.

 chown "www-data", "/var/www/html";

 chown "www-data", "/var/www/html",
                        recursive => 1;

=cut

sub chown {
   my ($user, $file, @opts) = @_;
   my $options = { @opts };

   my $recursive = "";
   if(exists $options->{"recursive"} && $options->{"recursive"} == 1) {
      $recursive = " -R ";
   }

   run "chown $recursive $user $file";
   if($? != 0) { die("Can't chown $file"); }
}

=item chgrp($group, $file)

Change the group of a file or a directory.

 chgrp "nogroup", "/var/www/html";

 chgrp "nogroup", "/var/www/html",
                     recursive => 1;

=cut

sub chgrp {
   my ($group, $file, @opts) = @_;
   my $options = { @opts };

   my $recursive = "";
   if(exists $options->{"recursive"} && $options->{"recursive"} == 1) {
      $recursive = " -R ";
   }

   run "chgrp $recursive $group $file";
   if($? != 0) { die("Can't chgrp $file"); }
}

=item chmod($mode, $file)

Change the permissions of a file or a directory.

 chmod 755, "/var/www/html";

 chmod 755, "/var/www/html",
               recursive => 1;

=cut

sub chmod {
   my ($mode, $file, @opts) = @_;
   my $options = { @opts };

   my $recursive = "";
   if(exists $options->{"recursive"} && $options->{"recursive"} == 1) {
      $recursive = " -R ";
   }

   run "chmod $recursive $mode $file";
   if($? != 0) { die("Can't chmod $file"); }
}


=item stat($file)

This function will return a hash with the following information about a file or directory.

=over 4

=item mode

=item size

=item uid

=item gid

=item atime

=item mtime

=back

 task "stat", "server01", sub {
    my %file_stat = stat("/etc/passwd");
 };


=cut

sub stat {
   my %ret;

   Rex::Logger::debug("Getting fs stat from $_[0]");

   if(my $sftp = Rex::get_sftp()) {
      %ret = $sftp->stat($_[0]);

      unless(%ret) {
         Rex::Logger::debug("Can't stat $_[0]");
         die("Can't stat $_[0]");
      }

      $ret{'mode'} = sprintf("%04o", $ret{'mode'} & 07777);
   } else {
      if(my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
               $atime, $mtime, $ctime, $blksize, $blocks) = CORE::stat($_[0])) {
         $ret{'mode'}  = sprintf("%04o", $mode & 07777);
         $ret{'size'}  = $size;
         $ret{'uid'}   = $uid;
         $ret{'gid'}   = $gid;
         $ret{'atime'} = $atime;
         $ret{'mtime'} = $mtime;
      }
      else {
         Rex::Logger::debug("Can't stat $_[0]");
         die("Can't stat $_[0]");
      }
   }

   return %ret;
}

=item is_file($file)

This function tests if $file is a file. Returns 1 if true. 0 if false.

 task "isfile", "server01", sub {
    if( is_file("/etc/passwd") ) {
       say "it is a file.";
    }
    else {
       say "hm, this is not a file.";
    }
 };

=cut

sub is_file {
   Rex::Logger::debug("Checking if $_[0] is a file");

   if(my $sftp = Rex::get_sftp()) {
      if( $sftp->opendir($_[0]) ) {
         return 0;
      }

      if( ! $sftp->open($_[0], O_RDONLY) ) {
         return 0;
      }
   } else {
      if(! -f $_[0]) {
         return 0;
      }
   }

   return 1;
}

=item is_dir($dir)

This function tests if $dir is a directory. Returns 1 if true. 0 if false.

 task "isdir", "server01", sub {
    if( is_dir("/etc") ) {
       say "it is a directory.";
    }
    else {
       say "hm, this is not a directory.";
    }
 };

=cut

sub is_dir {
   Rex::Logger::debug("Checking if $_[0] is a directory");

   if(my $sftp = Rex::get_sftp()) {
      if( ! $sftp->opendir($_[0]) ) {
         return 0;
      }
   } else {
      if( ! -d $_[0]) {
         return 0;
      }
   }

   return 1;
}

=item is_readable($file)

This function tests if $file is readable. It returns 1 if true. 0 if false.

 task "readable", "server01", sub {
    if( is_readable("/etc/passwd") ) {
       say "passwd is readable";
    }
    else {
       say "not readable.";
    }
 };

=cut


sub is_readable {
   Rex::Logger::debug("Checking if $_[0] is readable");

   if(my $ssh = Rex::is_ssh()) {
      net_ssh2_exec($ssh, "perl -le 'if(-r \"$_[0]\") { exit 0; } exit 1'");
      if($? == 0) {
         return 1;
      }
   } else {
      if(-r $_[0]) {
         return 1;
      }
   }

   return 0;
}

=item is_writable($file)

This function tests if $file is writable. It returns 1 if true. 0 if false.

 task "writable", "server01", sub {
    if( is_writable("/etc/passwd") ) {
       say "passwd is writable";
    }
    else {
       say "not writable.";
    }
 };

=cut


sub is_writable {
   Rex::Logger::debug("Checking if $_[0] is writable");

   if(my $ssh = Rex::is_ssh()) {
      net_ssh2_exec($ssh, "perl -le 'if(-w \"$_[0]\") { exit 0; } exit 1'");
      if($? == 0) {
         return 1;
      }
   } else {
      if(-w $_[0]) {
         return 1;
      }
   }

   return 0;
}

=item is_writeable($file)

This is only an alias for I<is_writable>.

=cut

sub is_writeable {
   is_writable(@_);
}

=item readlink($link)

This function returns the link endpoint if $link is a symlink. If $link is not a symlink it will die.


 task "islink", "server01", sub {
    my $link;
    eval {
       $link = readlink("/tmp/testlink");
    };

    say "this is a link" if($link);
 };

=cut

sub readlink {
   my $link;
   Rex::Logger::debug("Reading link of $_[0]");

   if(my $sftp = Rex::get_sftp()) {
      $link = $sftp->readlink($_[0]);
   } else {
      $link = CORE::readlink($_[0]);
   }

   unless($link) {
      Rex::Logger::debug("readlink: $_[0] is not a link.");
      die("readlink: $_[0] is not a link.");
   }

   return $link;
}

=item rename($old, $new)

This function will rename $old to $new. Will return 1 on success and 0 on failure.

 task "rename", "server01", sub {
    rename("/tmp/old", "/tmp/new");
 };

=cut

sub rename {
   my ($old, $new) = @_;

   Rex::Logger::debug("Renaming $old to $new");

   my $ret;
   if(my $sftp = Rex::get_sftp()) {
      $ret = $sftp->rename($old, $new);
   } else {
      $ret = CORE::rename($old, $new);
   }

   unless($ret) {
      Rex::Logger::info("Rename failed ($old -> $new)");
      die("Rename failed $old -> $new");
   }

}

=item mv($old, $new)

mv is an alias for I<rename>.

=cut

sub mv {
   return &rename(@_);
}

=item chdir($newdir)

This function will change the current workdirectory to $newdir. This function currently only works local.

 task "chdir", "server01", sub {
    chdir("/tmp");
 };

=cut

sub chdir {
   Rex::Logger::info("chdir behaviour will be changed in the future.");
   CORE::chdir($_[0]);
}

=item cd($newdir)

This is an alias of I<chdir>.

=cut

sub cd {
   &chdir($_[0]);
}

=item df([$device])

This function returns a hashRef reflecting the output of I<df>

 task "df", "server01", sub {
     my $df = df();
     my $df_on_sda1 = df("/dev/sda1");
 };


=cut

sub df {
   my ($dev) = @_;

   my $ret = {};

   $dev ||= "";

   my @lines = run "df $dev";
   shift @lines;

   for my $line (@lines) {
      my ($fs, $size, $used, $free, $use_per, $mounted_on) = split(/\s+/, $line, 6);

      $ret->{$fs} = {
         size => $size,
         used => $used,
         free => $free,
         used_perc => $use_per,
         mounted_on => $mounted_on
      };
   }

   if($dev) {
      return $ret->{$dev};
   }

   return $ret;
}

=item du($path)

Returns the disk usage of $path.

 task "du", "server01", sub {
    say "size of /var/www: " . du("/var/www");
 };

=cut

sub du {
   my ($path) = @_;

   my @lines = run "du -s $path";
   my ($du) = ($lines[0] =~ m/^(\d+)/);

   return $du;
}

=item cp($source, $destination)

cp will copy $source to $destination (it is recursive)

 task "cp", "server01", sub {
     cp("/var/www", "/var/www.old");
 };

=cut

sub cp {
   my ($source, $dest) = @_;

   run "cp -a $source $dest";
   if($? != 0) {
      die("Copy failed from $source to $dest");
   }
}

=item mount($device, $mount_point, @options)

Mount devices.

 task "mount", "server01", sub {
    mount "/dev/sda5", "/tmp";
    mount "/dev/sda6", "/mnt/sda6",
               fs => "ext3",
               options => [qw/noatime async/];
 };

=cut
sub mount {
   my ($device, $mount_point, @options) = @_;
   my $option = { @options };

   my $cmd = sprintf("mount %s %s %s %s",
                           $option->{"fs"}?"-t " . $option->{"fs"}:"",   # file system
                           $option->{"options"}?" -o " . join(",", @{$option->{"options"}}):"",
                           $device,
                           $mount_point);

   run $cmd;
   if($? != 0) { die("Mount failed of $mount_point"); }
}

=item umount($mount_point)

Unmount device.

 task "umount", "server01", sub {
    umount "/tmp";
 };

=cut
sub umount {
   my ($mount_point) = @_;
   run "umount $mount_point";

   if($? != 0) { die("Umount failed of $mount_point"); }
}

=item glob($glob)

 task "glob", "server1", sub {
    my @files_with_p = grep { is_file($_) } glob("/etc/p*");
 };

=cut
sub glob {
   my ($glob) = @_;

   if(my $ssh = Rex::is_ssh()) {
      my $content = run "perl -MData::Dumper -le'print Dumper [ glob(\"$glob\") ]'";
      $content =~ s/^\$VAR1 =/return /;
      my $tmp = eval $content;
      return @{$tmp};
   }
   else {
      return CORE::glob($glob);
   }

}

=back

=cut


1;
