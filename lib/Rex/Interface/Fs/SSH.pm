#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Fs::SSH;
   
use strict;
use warnings;

use Fcntl;
use Rex::Interface::Exec;
use Rex::Interface::Fs::Base;
use base qw(Rex::Interface::Fs::Base);

require Rex::Commands;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub ls {
   my ($self, $path) = @_;

   my @ret;

   Rex::Commands::profiler()->start("ls: $path");
   eval {

      my $sftp = Rex::get_sftp();
      my $dir = $sftp->opendir($path);
      unless($dir) {
         die("$path is not a directory");
      }

      while(my $entry  = $dir->read) {
         push @ret, $entry->{'name'};
      }
   };
   Rex::Commands::profiler()->end("ls: $path");

   # failed open directory, return undef
   if($@) { return; }

   # return directory content
   return @ret;
}

sub is_dir {
   my ($self, $path) = @_;

   my $ret = 0;

   Rex::Commands::profiler()->start("is_dir: $path");
   my $sftp = Rex::get_sftp();
   if($sftp->opendir($path)) {
      # return true if $path can be opened as a directory
      $ret = 1;
   }
   Rex::Commands::profiler()->end("is_dir: $path");

   return $ret;
}

sub is_file {
   my ($self, $file) = @_;

   my $ret;

   Rex::Commands::profiler()->start("is_file: $file");
   my $sftp = Rex::get_sftp();
   if( $sftp->opendir($file) ) {
   }

   if( $sftp->open($file, O_RDONLY) ) {
      # return true if $file can be opened read only
      $ret = 1;
   }
   Rex::Commands::profiler()->end("is_file: $file");

   return $ret;
}

sub unlink {
   my ($self, @files) = @_;

   my $sftp = Rex::get_sftp();
   for my $file (@files) {
      Rex::Commands::profiler()->start("unlink: $file");
      eval { $sftp->unlink($file); };
      Rex::Commands::profiler()->end("unlink: $file");
   }
}

sub mkdir {
   my ($self, $dir) = @_;

   my $ret;

   Rex::Commands::profiler()->start("mkdir: $dir");
   my $sftp = Rex::get_sftp();

   $sftp->mkdir($dir);
   if($self->is_dir($dir)) {
      $ret = 1;
   }

   Rex::Commands::profiler()->end("mkdir: $dir");

   return $ret;
}

sub stat {
   my ($self, $file) = @_;

   Rex::Commands::profiler()->start("stat: $file");

   my $sftp = Rex::get_sftp();
   my %ret = $sftp->stat($file);

   if(! %ret) { return; }

   $ret{'mode'} = sprintf("%04o", $ret{'mode'} & 07777);

   Rex::Commands::profiler()->end("stat: $file");

   return %ret;
}

sub is_readable {
   my ($self, $file) = @_;

   Rex::Commands::profiler()->start("is_readable: $file");

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("perl -le 'if(-r \"$file\") { exit 0; } exit 1'");

   Rex::Commands::profiler()->end("is_readable: $file");

   if($? == 0) { return 1; }
}

sub is_writable {
   my ($self, $file) = @_;

   Rex::Commands::profiler()->start("is_writable: $file");

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("perl -le 'if(-w \"$file\") { exit 0; } exit 1'");

   Rex::Commands::profiler()->end("is_writable: $file");

   if($? == 0) { return 1; }
}

sub readlink {
   my ($self, $file) = @_;

   my $ret;

   Rex::Commands::profiler()->start("readlink: $file");

   my $sftp = Rex::get_sftp();
   $ret = $sftp->readlink($file);

   Rex::Commands::profiler()->end("readlink: $file");

   return $ret;
}

sub rename {
   my ($self, $old, $new) = @_;

   my $ret;

   Rex::Commands::profiler()->start("rename: $old -> $new");

   my $sftp = Rex::get_sftp();
   $sftp->rename($old, $new);

   if( (! $self->is_file($old) && ! $self->is_dir($old) ) && ( $self->is_file($new) || $self->is_dir($new)) ) {
      $ret = 1;
   }

   Rex::Commands::profiler()->end("rename: $old -> $new");

   return $ret;
}

sub glob {
   my ($self, $glob) = @_;

   Rex::Commands::profiler()->start("glob: $glob");

   my $ssh = Rex::is_ssh();
   my $exec = Rex::Interface::Exec->create;
   my $content = $exec->exec("perl -MData::Dumper -le'print Dumper [ glob(\"$glob\") ]'");
   $content =~ s/^\$VAR1 =/return /;
   my $tmp = eval $content;

   Rex::Commands::profiler()->end("glob: $glob");

   return @{$tmp};
}

sub upload {
   my ($self, $source, $target) = @_;

   Rex::Commands::profiler()->start("upload: $source -> $target");

   my $ssh = Rex::is_ssh();
   unless($ssh->scp_put($source, $target)) {
      Rex::Logger::debug("upload: $target is not writable");

      Rex::Commands::profiler()->end("upload: $source -> $target");

      die("upload: $target is not writable.");
   }

   Rex::Commands::profiler()->end("upload: $source -> $target");
}

sub download {
   my ($self, $source, $target) = @_;

   Rex::Commands::profiler()->start("download: $source -> $target");

   my $ssh = Rex::is_ssh();
   if(!$ssh->scp_get($source, $target)) {
      Rex::Commands::profiler()->end("download: $source -> $target");
      die($ssh->error);
   }

   Rex::Commands::profiler()->end("download: $source -> $target");
}

1;
