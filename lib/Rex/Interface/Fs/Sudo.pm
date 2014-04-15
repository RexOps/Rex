#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs::Sudo;

use strict;
use warnings;

require Rex::Commands;
use Rex::Interface::Fs::Base;
use Rex::Helper::Path;
use Rex::Helper::Encode;
use JSON::XS;
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

  my @out = split(/\n/, $self->_exec("ls -a1 $path"));
  # failed open directory, return undef
  if($? != 0) { return; }

  @ret = grep { ! m/^\.\.?$/ } @out;

  # return directory content
  return @ret;
}

sub upload {
  my ($self, $source, $target) = @_;

  my $rnd_file = get_tmp_file;

  if(my $ssh = Rex::is_ssh()) {
    if(ref $ssh eq "Net::OpenSSH") {
      $ssh->sftp->put($source, $rnd_file);
    }
    else {
      $ssh->scp_put($source, $rnd_file);
    }
    $self->_exec("mv $rnd_file '$target'");
  }
  else {
    $self->cp($source, $target);
  }

}

sub download {
  my ($self, $source, $target) = @_;

  my $rnd_file = get_tmp_file;

  if(my $ssh = Rex::is_ssh()) {
    $self->_exec("cp '$source' $rnd_file");
    if(ref $ssh eq "Net::OpenSSH") {
      $ssh->sftp->get($rnd_file, $target);
    }
    else {
      $ssh->scp_get($rnd_file, $target);
    }
    $self->unlink($rnd_file);
  }
  else {
    $self->cp($source, $target);
  }

}

sub is_dir {
  my ($self, $path) = @_;

  $self->_exec("/bin/sh -c '[ -d \"$path\" ]'");
  my $ret = $?;

  if($ret == 0) { return 1; }
}

sub is_file {
  my ($self, $file) = @_;

  $self->_exec("/bin/sh -c '[ -e \"$file\" ]'");
  my $ret = $?;

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
  unlink $0;

  if(my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
          $atime, $mtime, $ctime, $blksize, $blocks) = stat($ARGV[0])) {

      my %ret;

      $ret{'mode'}  = sprintf("%04o", $mode & 07777);
      $ret{'size'}  = $size;
      $ret{'uid'}  = $uid;
      $ret{'gid'}  = $gid;
      $ret{'atime'} = $atime;
      $ret{'mtime'} = $mtime;

      print to_json(\%ret);
  }

  |;

  $script .= func_to_json();

  my $rnd_file = $self->_write_to_rnd_file($script);
  my $out = $self->_exec("perl $rnd_file '$file'");
  my $tmp = decode_json($out);

  return %{$tmp};
}

sub is_readable {
  my ($self, $file) = @_;
  my $script = q|unlink $0; if(-r $ARGV[0]) { exit 0; } exit 1; |;

  my $rnd_file = $self->_write_to_rnd_file($script);
  $self->_exec("perl $rnd_file '$file'");
  my $ret = $?;

  if($ret == 0) { return 1; }
}

sub is_writable {
  my ($self, $file) = @_;

  my $script = q|unlink $0; if(-w $ARGV[0]) { exit 0; } exit 1; |;

  my $rnd_file = $self->_write_to_rnd_file($script);
  $self->_exec("perl $rnd_file '$file'");
  my $ret = $?;

  if($ret == 0) { return 1; }
}

sub readlink {
  my ($self, $file) = @_;
  my $script = q|unlink $0; print readlink($ARGV[0]) . "\n"; |;

  my $rnd_file = $self->_write_to_rnd_file($script);
  my $out = $self->_exec("perl $rnd_file '$file'");
  chomp $out;

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
  unlink $0;
  print to_json([ glob("| . $glob . q|") ]);
  |;

  $script .= func_to_json();

  my $rnd_file = $self->_write_to_rnd_file($script);
  my $content = $self->_exec("perl $rnd_file");
  my $tmp = decode_json($content);

  return @{$tmp};
}

sub _get_file_writer {
  my ($self) = @_;

  my $fh;
  if(my $o = Rex::is_ssh()) {
    if(ref $o eq "Net::OpenSSH") {
      $fh = Rex::Interface::File->create("OpenSSH");
    }
    else {
      $fh = Rex::Interface::File->create("SSH");
    }
  }
  else {
    $fh = Rex::Interface::File->create("Local");
  }

  return $fh;
}

sub _write_to_rnd_file {
  my ($self, $content) = @_;
  my $fh = $self->_get_file_writer();
  my $rnd_file = get_tmp_file;

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
