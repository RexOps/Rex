#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Fs - File system commands

=head1 DESCRIPTION

With this module you can do file system tasks like creating directories, deleting or moving files, and more.

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

=cut

package Rex::Commands::Fs;

use strict;
use warnings;

# VERSION

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

=head2 Changing content

These commands are supposed to change the contents of the file system.

=head3 symlink($from, $to)

This function will create a symbolic link from C<$from> to C<$to>.

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
  if ( $fs->is_symlink($to) && $fs->readlink($to) eq $from ) {
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

=head3 ln($from, $to)

C<ln> is an alias for C<symlink>

=cut

sub ln {
  &symlink(@_);
}

=head3 unlink($file)

This function will remove the given C<$file>.

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

    if ( $fs->is_file($file) || $fs->is_symlink($file) ) {
      $fs->unlink($file);

      my $tmp_path = Rex::Config->get_tmp_dir;
      if ( $file !~ m/^\Q$tmp_path\E[\/\\][a-z]+\.tmp$/ ) { # skip tmp rex files
        Rex::get_current_connection()->{reporter}
          ->report( changed => 1, message => "File $file removed." );
      }
    }
    else {
      Rex::get_current_connection()->{reporter}->report( changed => 0, );
    }

    Rex::get_current_connection()->{reporter}
      ->report_resource_end( type => "unlink", name => $file );
  }
  else {
    &unlink($_) for @{$f};
  }

}

=head3 rm($file)

This is an alias for C<unlink>.

=cut

sub rm {
  &unlink(@_);
}

=head3 rmdir($dir)

This function will remove the given directory.

 task "rmdir", "server01", sub {
   rmdir("/tmp");
 };


With Rex-0.45 and newer, please use the L<file|Rex::Commands::File#file> resource instead.

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

=head3 mkdir($newdir)

This function will create a new directory.

The following options are supported:

=over 4

=item * owner

=item * group

=item * mode

=item * on_change

=back

With Rex-0.45 and newer, please use the L<file|Rex::Commands::File#file> resource instead.

 task "prepare", sub {
   file "/tmp",
     ensure => "directory",
     owner  => "root",
     group  => "root",
     mode   => 1777;
 };

Direct usage:
 
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

  $options->{on_change} //= sub { };

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
    &chmod( $mode, $dir )  if $mode;
  }
  else {
    my @splitted_dir;

    if ( Rex::is_ssh == 0 && $^O =~ m/^MSWin/ ) {

      # special case for local windows runs
      @splitted_dir = map { "\\$_"; } split( /[\\\/]/, $dir );
      if ( $splitted_dir[0] =~ m/([a-z]):/i ) {
        $splitted_dir[0] = "$1:\\";
      }
      else {
        $splitted_dir[0] =~ s/^\\//;
      }
    }
    else {
      @splitted_dir = map { "/$_"; } split( /\//, $dir );

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
        &chmod( $mode, $str_part )  if $mode;
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
  else {
    $options->{on_change}->($dir);
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "mkdir", name => $dir );

  return 1;
}

=head3 chown($owner, $path)

Change the owner of a file or a directory.

 chown "www-data", "/var/www/html";
 
 chown "www-data", "/var/www/html",
                recursive => 1;


This command will not be reported.

If you want to use reports, please use the L<file|Rex::Commands::File#file> resource instead.

=cut

sub chown {
  my ( $user, $file, @opts ) = @_;

  $file = resolv_path($file);
  my $fs = Rex::Interface::Fs->create;
  $fs->chown( $user, $file, @opts ) or die("Can't chown $file");
}

=head3 chgrp($group, $path)

Change the group of a file or a directory.

 chgrp "nogroup", "/var/www/html";
 
 chgrp "nogroup", "/var/www/html",
              recursive => 1;


This command will not be reported.

If you want to use reports, please use the L<file|Rex::Commands::File#file> resource instead.

=cut

sub chgrp {
  my ( $group, $file, @opts ) = @_;
  $file = resolv_path($file);

  my $fs = Rex::Interface::Fs->create;
  $fs->chgrp( $group, $file, @opts ) or die("Can't chgrp $file");
}

=head3 chmod($mode, $path)

Change the permissions of a file or a directory.

 chmod 755, "/var/www/html";
 
 chmod 755, "/var/www/html",
          recursive => 1;


This command will not be reported.

If you want to use reports, please use the L<file|Rex::Commands::File#file> resource instead.

=cut

sub chmod {
  my ( $mode, $file, @opts ) = @_;
  $file = resolv_path($file);

  my $fs = Rex::Interface::Fs->create;
  $fs->chmod( $mode, $file, @opts ) or die("Can't chmod $file");
}

=head3 rename($old, $new)

This function will rename C<$old> to C<$new>. Will return 1 on success and 0 on failure.

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

=head3 mv($old, $new)

C<mv> is an alias for C<rename>.

=cut

sub mv {
  return &rename(@_);
}

=head3 cp($source, $destination)

C<cp> will copy C<$source> to C<$destination> recursively.

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

=head2 Not changing content

These commands should not change the contents of the file system.

=head3 list_files("/path");

This function lists all entries (files, directories, ...) in a given directory and returns them as an array.

 task "ls-etc", "server01", sub {
   my @tmp_files = grep { /\.tmp$/ } list_files("/etc");
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

=head3 ls($path)

Just an alias for C<list_files>.

=cut

sub ls {
  return list_files(@_);
}

=head3 stat($file)

This function will return a hash with the following information about a file or directory:

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

  # may return undef, so capture into a list first.
  my @stat = $fs->stat($file);
  die("Can't stat $file") if ( !defined $stat[0] && scalar @stat == 1 );

  if ( scalar @stat % 2 ) {
    Rex::Logger::debug( 'stat output: ' . join ', ', @stat );
    die('stat returned odd number of elements');
  }

  %ret = @stat;

  return %ret;
}

=head3 is_file($path)

This function tests if C<$path> is a file. Returns 1 if true, 0 if false.

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

=head3 is_dir($path)

This function tests if C<$path> is a directory. Returns 1 if true, 0 if false.

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

=head3 is_symlink($path)

This function tests if C<$path> is a symbolic link. Returns 1 if true, 0 if false.

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

=head3 is_readable($path)

This function tests if C<$path> is readable. It returns 1 if true, 0 if false.

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

=head3 is_writable($path)

This function tests if C<$path> is writable. It returns 1 if true, 0 if false.

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

=head3 is_writeable($file)

This is only an alias for C<is_writable>.

=cut

sub is_writeable {
  is_writable(@_);
}

=head3 readlink($link)

If C<$link> is a symbolic link, returns the path it resolves to, and C<die()>s otherwise.

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

=head3 chdir($newdir)

This function will change the working directory to C<$newdir>. This function currently works only locally.

 task "chdir", "server01", sub {
   chdir("/tmp");
 };

This command will not be reported.

=cut

sub chdir {
  Rex::Logger::debug("chdir behaviour will be changed in the future.");
  CORE::chdir( $_[0] );
}

=head3 cd($newdir)

This is an alias of C<chdir>.

=cut

sub cd {
  &chdir( $_[0] );
}

=head3 df([$device])

This function returns a hash reference which reflects the output of C<df>.

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

=head3 du($path)

Returns the disk usage of C<$path>.

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

=head3 mount($device, $mount_point, @options)

Mount devices.

 task "mount", "server01", sub {
   mount "/dev/sda5", "/tmp";
   mount "/dev/sda6", "/mnt/sda6",
          ensure    => "present",
          type      => "ext3",
          options   => [qw/noatime async/],
          on_change => sub { say "device mounted"; };
   #
   # mount persistent with entry in /etc/fstab
 
   mount "/dev/sda6", "/mnt/sda6",
          ensure     => "persistent",
          type       => "ext3",
          options    => [qw/noatime async/],
          on_change  => sub { say "device mounted"; };
 
   # to umount a device
   mount "/dev/sda6", "/mnt/sda6",
          ensure => "absent";
 
 };

In order to be more aligned with C<mount> terminology, the previously used C<fs> option has been deprecated in favor of the C<type> option. The C<fs> option is still supported and works as previously, but Rex prints a warning if it is being used. There's also a warning if both C<fs> and C<type> options are specified, and in this case C<type> will be used.

=cut

sub mount {
  my ( $device, $mount_point, @options ) = @_;
  my $option = {@options};

  if ( defined $option->{fs} ) {
    Rex::Logger::info(
      'The `fs` option of the mount command has been deprecated in favor of the `type` option. Please update your task.',
      'warn'
    );

    if ( !defined $option->{type} ) {
      $option->{type} = $option->{fs};
    }
    else {
      Rex::Logger::info(
        'Both `fs` and `type` options have been specified for mount command. Preferring `type`.',
        'warn'
      );
    }
  }

  delete $option->{fs};

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "mount", name => "$mount_point" );

  $option->{ensure} ||= "present"; # default

  if ( $option->{ensure} eq "absent" ) {
    &umount(
      $mount_point,
      device    => $device,
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
      $option->{type} ? "-t " . $option->{type} : "", # file system
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
      if ( !exists $option->{type} ) {

        # no fs given, so get it from mount output
        my ( $out, $err ) = $exec->exec("mount");
        my @output = split( /\r?\n/, $out );
        my ($line) = grep { /^$device/ } @output;
        my ( $_d, $_o, $_p, $_t, $fs_type ) = split( /\s+/, $line );
        $option->{type} = $fs_type;

        my ($_options) = ( $line =~ m/\((.+?)\)/ );
        $option->{options} = $_options;
      }

      my $fh = Rex::Interface::File->create;

      my $old_md5 = md5("/etc/fstab");

      if ( !$fh->open( "<", "/etc/fstab" ) ) {
        Rex::Logger::debug("Can't open /etc/fstab for reading.");
        die("Can't open /etc/fstab for reading.");
      }

      my $f       = Rex::FS::File->new( fh => $fh );
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
              . "\t$mount_point\t$option->{type}\t$mountops\t0 0\n" );
        }
        else {
          push( @new_content,
            "$device\t$mount_point\t$option->{type}\t$mountops\t0 0\n" );
        }
      }
      else {
        if ( $option->{label} ) {
          push( @new_content,
                "LABEL="
              . $option->{label}
              . "\t$mount_point\t$option->{type}\t$option->{options}\t0 0\n" );
        }
        else {
          push( @new_content,
            "$device\t$mount_point\t$option->{type}\t$option->{options}\t0 0\n"
          );
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

=head3 umount($mount_point)

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
    $exec->exec("umount $mount_point");
    if ( $? != 0 ) { die("Umount failed of $mount_point"); }
    $changed = 1;
  }

  if ($changed) {
    if ( exists $option{on_change} && ref $option{on_change} eq "CODE" ) {
      $option{on_change}->( $mount_point, %option );
    }
    Rex::get_current_connection()->{reporter}
      ->report( changed => 1, message => "Unmounted $mount_point." );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "umount", name => "$mount_point" );
}

=head3 glob($glob)

Returns the list of filename expansions for C<$glob> as L<Perl's built-in glob|https://perldoc.perl.org/functions/glob.html> would do.

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

1;
