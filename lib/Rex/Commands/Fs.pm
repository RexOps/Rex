#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
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

require Rex::Exporter;
use Data::Dumper;
use Fcntl;
use Rex::Helper::SSH2;
use Rex::Helper::Path;
use Rex::Commands;
use Rex::Interface::Fs;
use Rex::Interface::Exec;
use Rex::Interface::File;
use File::Basename;
use Rex::Commands::MD5;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(list_files ls
  unlink rm rmdir mkdir stat readlink symlink ln rename mv chdir cd cp
  chown chgrp chmod
  is_file is_dir is_readable is_writeable is_writable is_symlink
  df du
  mount umount
  glob);

use vars qw(%file_handles);

=item list_files("/path");

This function list all entries (files, directories, ...) in a given directory and returns a array.

 task "ls-etc", "server01", sub {
   my @tmp_files = grep { /\.tmp$/ } list_files("/etc");
 };

This command will not be reported.

=cut

sub list_files {
  my $path = shift;
  $path = resolv_path($path);

  my $fs  = Rex::Interface::Fs->create;
  my @ret = $fs->ls($path);

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
  my ( $from, $to ) = @_;
  $from = resolv_path($from);
  $to   = resolv_path($to);

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "symlink", name => $to );

  my $fs = Rex::Interface::Fs->create;
  if ( $fs->is_symlink($to) ) {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }
  else {
    $fs->ln( $from, $to ) or die("Can't link $from -> $to");
    Rex::get_current_connection()->{reporter}
      ->report( changed => 1, message => "Symlink created: $from -> $to." );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "symlink", name => $to );

  return 1;
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

  my $f;
  if ( ref $files[0] eq "ARRAY" ) {
    $f = $files[0];
  }
  else {
    $f = \@files;
  }

  if ( scalar @{$f} == 1 ) {
    my $file = resolv_path $f->[0];
    my $fs   = Rex::Interface::Fs->create;

    Rex::get_current_connection()->{reporter}
      ->report_resource_start( type => "unlink", name => $file );

    if ( !$fs->is_file($file) ) {
      Rex::get_current_connection()->{reporter}->report( changed => 0, );
    }
    else {
      $fs->unlink($file);
      if ( $fs->is_file($file) ) {
        die "Can't remove $file.";
      }

      my $tmp_path = Rex::Config->get_tmp_dir;
      if ( $file !~ m/^\Q$tmp_path\E[\/\\][a-z]+\.tmp$/ ) { # skip tmp rex files
        Rex::get_current_connection()->{reporter}
          ->report( changed => 1, message => "File $file removed." );
      }
    }

    Rex::get_current_connection()->{reporter}
      ->report_resource_end( type => "unlink", name => $file );
  }
  else {
    &unlink($_) for @{$f};
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


Since: 0.45 Please use the file() resource instead.

 task "prepare", sub {
   file "/tmp",
     ensure => "absent";
 };

=cut

sub rmdir {
  my @dirs = @_;

  my $d;
  if ( ref $dirs[0] eq "ARRAY" ) {
    $d = $dirs[0];
  }
  else {
    $d = \@dirs;
  }

  if ( scalar @{$d} == 1 ) {
    my $dir = resolv_path $d->[0];
    my $fs  = Rex::Interface::Fs->create;

    Rex::get_current_connection()->{reporter}
      ->report_resource_start( type => "rmdir", name => $dir );

    if ( !$fs->is_dir($dir) && $dir !~ m/[\*\[]/ ) {
      Rex::get_current_connection()->{reporter}->report( changed => 0, );
    }
    else {
      $fs->rmdir($dir);
      if ( $fs->is_dir($dir) ) {
        die "Can't remove $dir.";
      }

      Rex::get_current_connection()->{reporter}
        ->report( changed => 1, message => "Directory $dir removed." );
    }

    Rex::get_current_connection()->{reporter}
      ->report_resource_end( type => "rmdir", name => $dir );
  }
  else {
    &rmdir($_) for @{$d};
  }
}

=item mkdir($newdir)

This function will create a new directory.

Since: 0.45 Please use the file() resource instead.

 task "prepare", sub {
   file "/tmp",
     ensure => "directory",
     owner  => "root",
     group  => "root",
     mode   => 1777;
 };
 
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
  $dir = resolv_path($dir);

  my $options = {@_};

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "mkdir", name => $dir );

  my $fs = Rex::Interface::Fs->create;

  my $not_created = 0;
  my %old_stat;
  my $changed = 0;

  if ( $fs->is_dir($dir) ) {
    $not_created = 1;
    %old_stat    = &stat($dir);
  }

  my $mode          = $options->{"mode"}          || 755;
  my $owner         = $options->{"owner"}         || "";
  my $group         = $options->{"group"}         || "";
  my $not_recursive = $options->{"not_recursive"} || 0;

  if ($not_recursive) {
    if ( !$fs->mkdir($dir) ) {
      Rex::Logger::debug("Can't create directory $dir");
      die("Can't create directory $dir");
    }

    &chown( $owner, $dir ) if $owner;
    &chgrp( $group, $dir ) if $group;
    &chmod( $mode, $dir ) if $owner;
  }
  else {
    my @splitted_dir;

    if ( Rex::is_ssh == 0 && $^O =~ m/^MSWin/ ) {

      # special case for local windows runs
      @splitted_dir = map { $_ = "\\$_"; } split( /[\\\/]/, $dir );
      if ( $splitted_dir[0] =~ m/([a-z]):/i ) {
        $splitted_dir[0] = "$1:\\";
      }
      else {
        $splitted_dir[0] =~ s/^\\//;
      }
    }
    else {
      @splitted_dir = map { $_ = "/$_"; } split( /\//, $dir );

      unless ( $splitted_dir[0] eq "/" ) {
        $splitted_dir[0] = "." . $splitted_dir[0];
      }
      else {
        shift @splitted_dir;
      }
    }

    my $str_part = "";
    for my $part (@splitted_dir) {
      $str_part .= "$part";

      if ( !is_dir($str_part) && !is_file($str_part) ) {
        if ( !$fs->mkdir($str_part) ) {
          Rex::Logger::debug("Can't create directory $dir");
          die("Can't create directory $dir");
        }

        &chown( $owner, $str_part ) if $owner;
        &chgrp( $group, $str_part ) if $group;
        &chmod( $mode, $str_part ) if $owner;
      }
    }
  }

  my %new_stat = &stat($dir);

  if ( !$not_created ) {
    Rex::get_current_connection()->{reporter}
      ->report( changed => 1, message => "Directory created." );
    $changed = 1;
  }

  if ( %old_stat && $old_stat{uid} != $new_stat{uid} ) {
    Rex::get_current_connection()->{reporter}
      ->report( changed => 1, message => "Owner updated." );
    $changed = 1;
  }

  if ( %old_stat && $old_stat{gid} != $new_stat{gid} ) {
    Rex::get_current_connection()->{reporter}
      ->report( changed => 1, message => "Group updated." );
    $changed = 1;
  }

  if ( %old_stat && $old_stat{mode} ne $new_stat{mode} ) {
    Rex::get_current_connection()->{reporter}
      ->report( changed => 1, message => "Mode updated." );
    $changed = 1;
  }

  if ( $changed == 0 ) {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "mkdir", name => $dir );

  return 1;
}

=item chown($owner, $file)

Change the owner of a file or a directory.

 chown "www-data", "/var/www/html";
 
 chown "www-data", "/var/www/html",
                recursive => 1;


This command will not be reported.

If you want to use reports, please use the file() resource instead.

=cut

sub chown {
  my ( $user, $file, @opts ) = @_;

  $file = resolv_path($file);
  my $fs = Rex::Interface::Fs->create;
  $fs->chown( $user, $file, @opts ) or die("Can't chown $file");
}

=item chgrp($group, $file)

Change the group of a file or a directory.

 chgrp "nogroup", "/var/www/html";
 
 chgrp "nogroup", "/var/www/html",
              recursive => 1;


This command will not be reported.

If you want to use reports, please use the file() resource instead.

=cut

sub chgrp {
  my ( $group, $file, @opts ) = @_;
  $file = resolv_path($file);

  my $fs = Rex::Interface::Fs->create;
  $fs->chgrp( $group, $file, @opts ) or die("Can't chgrp $file");
}

=item chmod($mode, $file)

Change the permissions of a file or a directory.

 chmod 755, "/var/www/html";
 
 chmod 755, "/var/www/html",
          recursive => 1;


This command will not be reported.

If you want to use reports, please use the file() resource instead.

=cut

sub chmod {
  my ( $mode, $file, @opts ) = @_;
  $file = resolv_path($file);

  my $fs = Rex::Interface::Fs->create;
  $fs->chmod( $mode, $file, @opts ) or die("Can't chmod $file");
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


This command will not be reported.

=cut

sub stat {
  my ($file) = @_;
  $file = resolv_path($file);
  my %ret;

  Rex::Logger::debug("Getting fs stat from $file");

  my $fs = Rex::Interface::Fs->create;
  %ret = $fs->stat($file) or die("Can't stat $file");

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

This command will not be reported.

=cut

sub is_file {
  my ($file) = @_;
  $file = resolv_path($file);

  my $fs = Rex::Interface::Fs->create;
  return $fs->is_file($file);
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

This command will not be reported.

=cut

sub is_dir {
  my ($path) = @_;
  $path = resolv_path($path);

  my $fs = Rex::Interface::Fs->create;
  return $fs->is_dir($path);

}

=item is_symlink($file)

This function tests if $file is a symlink. Returns 1 if true. 0 if false.

 task "issym", "server01", sub {
   if( is_symlink("/etc/foo.txt") ) {
     say "it is a symlink.";
   }
   else {
     say "hm, this is not a symlink.";
   }
 };

This command will not be reported.

=cut

sub is_symlink {
  my ($path) = @_;
  $path = resolv_path($path);

  my $fs = Rex::Interface::Fs->create;
  return $fs->is_symlink($path);
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

This command will not be reported.

=cut

sub is_readable {
  my ($file) = @_;
  $file = resolv_path($file);
  Rex::Logger::debug("Checking if $file is readable");

  my $fs = Rex::Interface::Fs->create;
  return $fs->is_readable($file);
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

This command will not be reported.

=cut

sub is_writable {
  my ($file) = @_;
  $file = resolv_path($file);
  Rex::Logger::debug("Checking if $file is writable");

  my $fs = Rex::Interface::Fs->create;
  return $fs->is_writable($file);
}

=item is_writeable($file)

This is only an alias for I<is_writable>.

This command will not be reported.

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

This command will not be reported.

=cut

sub readlink {
  my ($file) = @_;
  $file = resolv_path($file);
  Rex::Logger::debug("Reading link of $file");

  my $fs   = Rex::Interface::Fs->create;
  my $link = $fs->readlink($file);

  unless ($link) {
    Rex::Logger::debug("readlink: $file is not a link.");
    die("readlink: $file is not a link.");
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
  my ( $old, $new ) = @_;
  $old = resolv_path($old);
  $new = resolv_path($new);

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "rename", name => "$old -> $new" );

  my $fs = Rex::Interface::Fs->create;

  my $old_present = 0;
  if ( $fs->is_file($old) || $fs->is_dir($old) || $fs->is_symlink($old) ) {
    $old_present = 1;
  }

  Rex::Logger::debug("Renaming $old to $new");

  if ( !$fs->rename( $old, $new ) ) {
    Rex::Logger::info("Rename failed ($old -> $new)");
    die("Rename failed $old -> $new");
  }

  my $new_present = 0;
  if ( $fs->is_file($new) || $fs->is_dir($new) || $fs->is_symlink($new) ) {
    $new_present = 1;
  }

  my $old_absent = 0;
  if ( !( $fs->is_file($old) || $fs->is_dir($old) || $fs->is_symlink($old) ) ) {
    $old_absent = 1;
  }

  if ( $old_present == 1 && $new_present == 1 && $old_absent == 1 ) {
    Rex::get_current_connection()->{reporter}->report( changed => 1 );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0 );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "rename", name => "$old -> $new" );
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

This command will not be reported.

=cut

sub chdir {
  Rex::Logger::debug("chdir behaviour will be changed in the future.");
  CORE::chdir( $_[0] );
}

=item cd($newdir)

This is an alias of I<chdir>.

=cut

sub cd {
  &chdir( $_[0] );
}

=item df([$device])

This function returns a hashRef reflecting the output of I<df>

 task "df", "server01", sub {
    my $df = df();
    my $df_on_sda1 = df("/dev/sda1");
 };

This command will not be reported.

=cut

sub df {
  my ($dev) = @_;

  my $ret = {};

  $dev ||= "";

  my $exec = Rex::Interface::Exec->create;
  my ( $out, $err ) = $exec->exec("df $dev 2>/dev/null");

  my @lines = split( /\r?\n/, $out );

  $ret = _parse_df(@lines);

  if ($dev) {
    if ( keys %$ret == 1 ) {
      ($dev) = keys %$ret;
    }
    return $ret->{$dev};
  }

  return $ret;
}

sub _parse_df {
  my @lines = @_;
  chomp @lines;

  my $ret = {};

  shift @lines;
  my $current_fs = "";

  for my $line (@lines) {
    my ( $fs, $size, $used, $free, $use_per, $mounted_on ) =
      split( /\s+/, $line, 6 );
    $current_fs = $fs if $fs;

    if ( !$size ) {
      next;
    }

    $ret->{$current_fs} = {
      size       => $size,
      used       => $used,
      free       => $free,
      used_perc  => $use_per,
      mounted_on => $mounted_on
    };
  }

  return $ret;
}

=item du($path)

Returns the disk usage of $path.

 task "du", "server01", sub {
   say "size of /var/www: " . du("/var/www");
 };

This command will not be reported.

=cut

sub du {
  my ($path) = @_;
  $path = resolv_path($path);

  my $exec  = Rex::Interface::Exec->create;
  my @lines = $exec->exec("du -s $path");
  my ($du)  = ( $lines[0] =~ m/^(\d+)/ );

  return $du;
}

=item cp($source, $destination)

cp will copy $source to $destination (it is recursive)

 task "cp", "server01", sub {
    cp("/var/www", "/var/www.old");
 };

=cut

sub cp {
  my ( $source, $dest ) = @_;

  $source = resolv_path($source);
  $dest   = resolv_path($dest);

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "cp", name => "$source -> $dest" );

  my $fs = Rex::Interface::Fs->create;

  my $new_present = 0;
  if ( $fs->is_file($source) && $fs->is_dir($dest) ) {
    $dest = "$dest/" . basename $source;
  }

  if ( $fs->is_file($dest) || $fs->is_dir($dest) || $fs->is_symlink($dest) ) {
    $new_present = 1;
  }

  if ( !$fs->cp( $source, $dest ) ) {
    die("Copy failed from $source to $dest");
  }

  if ( $new_present == 0 ) {
    Rex::get_current_connection()->{reporter}->report( changed => 1, );
  }
  else {
    Rex::get_current_connection()->{reporter}->report( changed => 0, );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "cp", name => "$source -> $dest" );
}

=item mount($device, $mount_point, @options)

Mount devices.

 task "mount", "server01", sub {
   mount "/dev/sda5", "/tmp";
   mount "/dev/sda6", "/mnt/sda6",
          ensure    => "present",
          fs        => "ext3",
          options   => [qw/noatime async/],
          on_change => sub { say "device mounted"; };
   #
   # mount persistent with entry in /etc/fstab
 
   mount "/dev/sda6", "/mnt/sda6",
          ensure     => "persistent",
          fs         => "ext3",
          options    => [qw/noatime async/],
          on_change  => sub { say "device mounted"; };
 
   # to umount a device
  mount "/dev/sda6", "/mnt/sda6",
          ensure => "absent";
 
 };

=cut

sub mount {
  my ( $device, $mount_point, @options ) = @_;
  my $option = {@options};

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "mount", name => "$mount_point" );

  $option->{ensure} ||= "present";    # default

  if ( $option->{ensure} eq "absent" ) {
    &umount(
      $mount_point,
      device => $device,
      on_change =>
        ( exists $option->{on_change} ? $option->{on_change} : undef )
    );
  }
  else {
    if ( $option->{ensure} eq "persistent" ) {
      $option->{persistent} = 1;
    }

    my $changed = 0;
    my $exec    = Rex::Interface::Exec->create;

    my ( $m_out, $m_err ) = $exec->exec("mount");
    my @mounted = split( /\r?\n/, $m_out );
    my ($already_mounted) = grep { m/$device on $mount_point/ } @mounted;
    if ($already_mounted) {
      Rex::Logger::debug("Device ($device) already mounted on $mount_point.");
      $changed = 0;
    }

    my $cmd = sprintf(
      "mount %s %s %s %s",
      $option->{"fs"} ? "-t " . $option->{"fs"} : "",    # file system
      $option->{"options"}
      ? " -o " . join( ",", @{ $option->{"options"} } )
      : "",
      $device,
      $mount_point
    );

    unless ($already_mounted) {
      $exec->exec($cmd);
      if ( $? != 0 ) { die("Mount failed of $mount_point"); }
      $changed = 1;
      Rex::get_current_connection()->{reporter}->report(
        changed => 1,
        message => "Device $device mounted on $mount_point."
      );
    }

    if ( exists $option->{persistent} ) {
      if ( !exists $option->{fs} ) {

        # no fs given, so get it from mount output
        my ( $out, $err ) = $exec->exec("mount");
        my @output = split( /\r?\n/, $out );
        my ($line) = grep { /^$device/ } @output;
        my ( $_d, $_o, $_p, $_t, $fs_type ) = split( /\s+/, $line );
        $option->{fs} = $fs_type;

        my ($_options) = ( $line =~ m/\((.+?)\)/ );
        $option->{options} = $_options;
      }

      my $fh = Rex::Interface::File->create;

      my $old_md5 = md5("/etc/fstab");

      if ( !$fh->open( "<", "/etc/fstab" ) ) {
        Rex::Logger::debug("Can't open /etc/fstab for reading.");
        die("Can't open /etc/fstab for reading.");
      }

      my $f = Rex::FS::File->new( fh => $fh );
      my @content = $f->read_all;
      $f->close;

      my @new_content = grep { !/^$device\s/ } @content;

      $option->{options} ||= "defaults";

      if ( ref( $option->{options} ) eq "ARRAY" ) {
        my $mountops = join( ",", @{ $option->{"options"} } );
        if ( $option->{label} ) {
          push( @new_content,
                "LABEL="
              . $option->{label}
              . "\t$mount_point\t$option->{fs}\t$mountops\t0 0\n" );
        }
        else {
          push( @new_content,
            "$device\t$mount_point\t$option->{fs}\t$mountops\t0 0\n" );
        }
      }
      else {
        if ( $option->{label} ) {
          push( @new_content,
                "LABEL="
              . $option->{label}
              . "\t$mount_point\t$option->{fs}\t$option->{options}\t0 0\n" );
        }
        else {
          push( @new_content,
            "$device\t$mount_point\t$option->{fs}\t$option->{options}\t0 0\n" );
        }
      }

      $fh = Rex::Interface::File->create;

      if ( !$fh->open( ">", "/etc/fstab" ) ) {
        Rex::Logger::debug("Can't open /etc/fstab for writing.");
        die("Can't open /etc/fstab for writing.");
      }

      $f = Rex::FS::File->new( fh => $fh );
      $f->write( join( "\n", @new_content ) );
      $f->close;

      my $new_md5 = md5("/etc/fstab");

      if ( $new_md5 ne $old_md5 ) {
        Rex::get_current_connection()->{reporter}
          ->report( changed => 1, message => "File /etc/fstab updated." );
        $changed = 1;
      }
    }

    if ( $changed == 1 ) {
      if ( exists $option->{on_change} && ref $option->{on_change} eq "CODE" ) {
        $option->{on_change}->( $device, $mount_point );
      }
    }
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "mount", name => "$mount_point" );
}

=item umount($mount_point)

Unmount device.

 task "umount", "server01", sub {
   umount "/tmp";
 };

=cut

sub umount {
  my ( $mount_point, %option ) = @_;

  my $device;

  if ( exists $option{device} ) {
    $device = $option{device};
  }

  my $exec = Rex::Interface::Exec->create;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "umount", name => "$mount_point" );

  my $changed = 0;
  my ( $m_out, $m_err ) = $exec->exec("mount");
  my @mounted = split( /\r?\n/, $m_out );
  my $already_mounted;

  if ($device) {
    ($already_mounted) = grep { m/$device on $mount_point/ } @mounted;
  }
  else {
    ($already_mounted) = grep { m/on $mount_point/ } @mounted;
  }

  if ($already_mounted) {
    $changed = 1;
  }

  $exec->exec("umount $mount_point");

  if ( $? != 0 ) { die("Umount failed of $mount_point"); }

  if ($changed) {
    if ( exists $option{on_change} && ref $option{on_change} eq "CODE" ) {
      $option{on_change}->( $mount_point, %option );
    }
    Rex::get_current_connection()->{reporter}
      ->report( chaned => 1, "Unmounted $mount_point." );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "umount", name => "$mount_point" );
}

=item glob($glob)

 task "glob", "server1", sub {
   my @files_with_p = grep { is_file($_) } glob("/etc/p*");
 };

This command will not be reported.

=cut

sub glob {
  my ($glob) = @_;
  $glob = resolv_path($glob);

  my $fs = Rex::Interface::Fs->create;
  return $fs->glob($glob);
}

=back

=cut

1;
