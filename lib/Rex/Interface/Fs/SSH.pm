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

   # failed open directory, return undef
   if($@) { return; }

   # return directory content
   return @ret;
}

sub is_dir {
   my ($self, $path) = @_;

   my $sftp = Rex::get_sftp();
   if($sftp->opendir($path)) {
      # return true if $path can be opened as a directory
      return 1;
   }
}

sub is_file {
   my ($self, $file) = @_;

   my $sftp = Rex::get_sftp();
   if( $sftp->opendir($file) ) {
      return;
   }

   if( $sftp->open($file, O_RDONLY) ) {
      # return true if $file can be opened read only
      return 1;
   }
}

sub unlink {
   my ($self, @files) = @_;

   my $sftp = Rex::get_sftp();
   for my $file (@files) {
      eval { $sftp->unlink($file); };
   }
}

sub mkdir {
   my ($self, $dir) = @_;
   my $sftp = Rex::get_sftp();

   $sftp->mkdir($dir);
   if($self->is_dir($dir)) {
      return 1;
   }
}

sub stat {
   my ($self, $file) = @_;

   my $sftp = Rex::get_sftp();
   my %ret = $sftp->stat($file);

   if(! %ret) { return; }

   $ret{'mode'} = sprintf("%04o", $ret{'mode'} & 07777);

   return %ret;
}

sub is_readable {
   my ($self, $file) = @_;

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("perl -le 'if(-r \"$file\") { exit 0; } exit 1'");

   if($? == 0) { return 1; }
}

sub is_writable {
   my ($self, $file) = @_;

   my $exec = Rex::Interface::Exec->create;
   $exec->exec("perl -le 'if(-w \"$file\") { exit 0; } exit 1'");

   if($? == 0) { return 1; }
}

sub readlink {
   my ($self, $file) = @_;

   my $sftp = Rex::get_sftp();
   return $sftp->readlink($file);
}

sub rename {
   my ($self, $old, $new) = @_;

   my $sftp = Rex::get_sftp();
   return $sftp->rename($old, $new);
}

sub glob {
   my ($self, $glob) = @_;

   my $ssh = Rex::is_ssh();
   my $exec = Rex::Interface::Exec->create;
   my $content = $exec->exec("perl -MData::Dumper -le'print Dumper [ glob(\"$glob\") ]'");
   $content =~ s/^\$VAR1 =/return /;
   my $tmp = eval $content;

   return @{$tmp};
}

1;
