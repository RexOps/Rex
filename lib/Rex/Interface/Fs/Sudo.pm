#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Fs::Sudo;
   
use strict;
use warnings;

require Rex::Commands;
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

   my $script = q|
      my @ret;
      use Data::Dumper;
      opendir(my $dh, "| . $path .  q|") or die("| . $path . q| is not a directory");
      while(my $entry = readdir($dh)) {
         next if ($entry =~ /^\.\.?$/);
         push @ret, $entry;
      }

      print Dumper(\@ret);
   |;

   my $rnd_file = $self->_write_to_rnd_file($script);

   my $out = $self->_exec("perl $rnd_file");
   $out =~ s/^\$VAR1 =/return /;
   my $tmp = eval $out;

   $self->unlink($rnd_file);

   # failed open directory, return undef
   if($@) { return; }

   # return directory content
   return @{$tmp};
}

sub upload {
   my ($self, $source, $target) = @_;

   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".tmp";

   if(my $ssh = Rex::is_ssh()) {
      $ssh->scp_put($source, $rnd_file);
      $self->_exec("mv $rnd_file '$target'");
   }
   else {
      $self->cp($source, $target);
   }

}

sub download {
   my ($self, $source, $target) = @_;

   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".tmp";

   if(my $ssh = Rex::is_ssh()) {
      $self->_exec("cp '$source' $rnd_file");
      $ssh->scp_get($rnd_file, $target);
      $self->unlink($rnd_file);
   }
   else {
      $self->cp($source, $target);
   }

}

sub is_dir {
   my ($self, $path) = @_;

   my $script = q|
      if(-d $ARGV[0]) { exit 0; } exit 1;
   |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   $self->_exec("perl $rnd_file '$path'");
   my $ret = $?;

   $self->unlink($rnd_file);

   if($ret == 0) { return 1; }
}

sub is_file {
   my ($self, $file) = @_;

   my $script = q|
      if(-f $ARGV[0]) { exit 0; } exit 1;
   |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   $self->_exec("perl $rnd_file '$file'");
   my $ret = $?;

   $self->unlink($rnd_file);

   if($ret == 0) { return 1; }
}

sub unlink {
   my ($self, @files) = @_;
   (@files) = $self->_normalize_path(@files);

   $self->_exec("rm " . join(" ", @files));
   if($? == 0) { return 1; }
}

sub mkdir {
   my ($self, $dir) = @_;
   $self->_exec("mkdir '$dir' >/dev/null 2>&1");
   if($? == 0) { return 1; }
}

sub stat {
   my ($self, $file) = @_;

   my $script = q|
   use Data::Dumper;
   if(my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
               $atime, $mtime, $ctime, $blksize, $blocks) = stat($ARGV[0])) {

         my %ret;

         $ret{'mode'}  = sprintf("%04o", $mode & 07777); 
         $ret{'size'}  = $size;
         $ret{'uid'}   = $uid;
         $ret{'gid'}   = $gid;
         $ret{'atime'} = $atime;
         $ret{'mtime'} = $mtime;

         print Dumper(\%ret);
   }

   |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   my $out = $self->_exec("perl $rnd_file '$file'");
   $out =~ s/^\$VAR1 =/return /;
   my $tmp = eval $out;
   $self->unlink($rnd_file);

   return %{$tmp};
}

sub is_readable {
   my ($self, $file) = @_;
   my $script = q| if(-r $ARGV[0]) { exit 0; } exit 1; |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   $self->_exec("perl $rnd_file '$file'");
   my $ret = $?;
   $self->unlink($rnd_file);

   if($ret == 0) { return 1; }
}

sub is_writable {
   my ($self, $file) = @_;

   my $script = q| if(-w $ARGV[0]) { exit 0; } exit 1; |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   $self->_exec("perl $rnd_file '$file'");
   my $ret = $?;
   $self->unlink($rnd_file);

   if($ret == 0) { return 1; }
}

sub readlink {
   my ($self, $file) = @_;
   my $script = q|print readlink($ARGV[0]) . "\n"; |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   my $out = $self->_exec("perl $rnd_file '$file'");
   chomp $out;
   
   $self->unlink($rnd_file);
   return $out;
}

sub rename {
   my ($self, $old, $new) = @_;
   ($old) = $self->_normalize_path($old);
   ($new) = $self->_normalize_path($new);

   $self->_exec("mv $old $new");

   if($? == 0) { return 1; }
}

sub glob {
   my ($self, $glob) = @_;

   my $script = q|
   use Data::Dumper;
   print Dumper [ glob("| . $glob . q|") ];
   |;

   my $rnd_file = $self->_write_to_rnd_file($script);
   my $content = $self->_exec("perl $rnd_file");
   $content =~ s/^\$VAR1 =/return /;
   my $tmp = eval $content;
   $self->unlink($rnd_file);

   return @{$tmp};
}

sub _get_file_writer {
   my ($self) = @_;

   my $fh;
   if(Rex::is_ssh()) {
      $fh = Rex::Interface::File->create("SSH");
   }
   else {
      $fh = Rex::Interface::File->create("Local");
   }

   return $fh;
}

sub _write_to_rnd_file {
   my ($self, $content) = @_;
   my $fh = $self->_get_file_writer();
   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".tmp";

   $fh->open(">", $rnd_file);
   $fh->write($content);
   $fh->close;

   return $rnd_file;
}

sub _exec {
   my ($self, $cmd) = @_;
   my $exec = Rex::Interface::Exec->create("Sudo");
   return $exec->exec($cmd);
}

1;
