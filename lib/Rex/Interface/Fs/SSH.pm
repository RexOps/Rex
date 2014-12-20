#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs::SSH;

use strict;
use warnings;

# VERSION

use Fcntl qw(:DEFAULT :mode);
use Rex::Helper::Encode;
use Rex::Interface::Exec;
use Rex::Interface::Fs::Base;
use base qw(Rex::Interface::Fs::Base);

require Rex::Commands;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub ls {
  my ( $self, $path ) = @_;

  my @ret;

  Rex::Commands::profiler()->start("ls: $path");
  eval {

    my $sftp = Rex::get_sftp();
    my $dir  = $sftp->opendir($path);
    unless ($dir) {
      die("$path is not a directory");
    }

    while ( my $entry = $dir->read ) {
      push @ret, $entry->{'name'};
    }
  };
  Rex::Commands::profiler()->end("ls: $path");

  # failed open directory, return undef
  if ($@) { return; }

  # return directory content
  return @ret;
}

sub is_dir {
  my ( $self, $path ) = @_;

  Rex::Commands::profiler()->start("is_dir: $path");

  my $sftp = Rex::get_sftp();
  my $stat = $sftp->stat($path);
  defined $stat ? return S_ISDIR( $stat->{mode} ) : return undef;

  Rex::Commands::profiler()->end("is_dir: $path");
}

sub is_file {
  my ( $self, $file ) = @_;

  Rex::Commands::profiler()->start("is_file: $file");

  my $sftp = Rex::get_sftp();
  my $stat = $sftp->stat($file);

  defined $stat
    ? return ( S_ISREG( $stat->{mode} )
      || S_ISLNK( $stat->{mode} )
      || S_ISBLK( $stat->{mode} )
      || S_ISCHR( $stat->{mode} )
      || S_ISFIFO( $stat->{mode} ) )
    : return undef;

  Rex::Commands::profiler()->end("is_file: $file");
}

sub unlink {
  my ( $self, @files ) = @_;

  my $sftp = Rex::get_sftp();
  for my $file (@files) {
    Rex::Commands::profiler()->start("unlink: $file");
    eval {
      $sftp->unlink($file);
      1;
    } or do {
      die "Error unlinking file: $file." if ( Rex::Config->get_autodie );
    };
    Rex::Commands::profiler()->end("unlink: $file");
  }
}

sub mkdir {
  my ( $self, $dir ) = @_;

  my $ret;

  Rex::Commands::profiler()->start("mkdir: $dir");
  my $sftp = Rex::get_sftp();

  $sftp->mkdir($dir);
  if ( $self->is_dir($dir) ) {
    $ret = 1;
  }
  else {
    die "Error creating directory: $dir." if ( Rex::Config->get_autodie );
  }

  Rex::Commands::profiler()->end("mkdir: $dir");

  return $ret;
}

sub stat {
  my ( $self, $file ) = @_;

  Rex::Commands::profiler()->start("stat: $file");

  my $sftp = Rex::get_sftp();
  my %ret  = $sftp->stat($file);

  if ( !%ret ) { return; }

  $ret{'mode'} = sprintf( "%04o", $ret{'mode'} & 07777 );

  Rex::Commands::profiler()->end("stat: $file");

  return %ret;
}

sub is_readable {
  my ( $self, $file ) = @_;

  Rex::Commands::profiler()->start("is_readable: $file");

  my $exec = Rex::Interface::Exec->create;
  $exec->exec("perl -le 'if(-r \"$file\") { exit 0; } exit 1'");

  Rex::Commands::profiler()->end("is_readable: $file");

  if ( $? == 0 ) { return 1; }
}

sub is_writable {
  my ( $self, $file ) = @_;

  Rex::Commands::profiler()->start("is_writable: $file");

  my $exec = Rex::Interface::Exec->create;
  $exec->exec("perl -le 'if(-w \"$file\") { exit 0; } exit 1'");

  Rex::Commands::profiler()->end("is_writable: $file");

  if ( $? == 0 ) { return 1; }
}

sub readlink {
  my ( $self, $file ) = @_;

  my $ret;

  Rex::Commands::profiler()->start("readlink: $file");

  my $sftp = Rex::get_sftp();
  $ret = $sftp->readlink($file);

  Rex::Commands::profiler()->end("readlink: $file");

  return $ret;
}

sub rename {
  my ( $self, $old, $new ) = @_;

  my $ret;

  Rex::Commands::profiler()->start("rename: $old -> $new");

  # don't use rename() doesn't work with different file systems / partitions
  my $exec = Rex::Interface::Exec->create;
  $exec->exec("/bin/mv '$old' '$new'");

  if ( ( !$self->is_file($old) && !$self->is_dir($old) )
    && ( $self->is_file($new) || $self->is_dir($new) ) )
  {
    $ret = 1;
  }
  else {
    die "Error renaming file or directory ($old -> $new)."
      if ( Rex::Config->get_autodie );
  }

  Rex::Commands::profiler()->end("rename: $old -> $new");

  return $ret;
}

sub glob {
  my ( $self, $glob ) = @_;

  Rex::Commands::profiler()->start("glob: $glob");

  my $ssh     = Rex::is_ssh();
  my $exec    = Rex::Interface::Exec->create;
  my $content = $exec->exec("perl -le'print join(\"*,*,*\", glob(\"$glob\"))'");
  chomp $content;
  my @files = split( /\*,\*,\*/, $content );

  Rex::Commands::profiler()->end("glob: $glob");

  return @files;
}

sub upload {
  my ( $self, $source, $target ) = @_;

  Rex::Commands::profiler()->start("upload: $source -> $target");

  my $ssh = Rex::is_ssh();
  unless ( $ssh->scp_put( $source, $target ) ) {
    Rex::Logger::debug("upload: $target is not writable");

    Rex::Commands::profiler()->end("upload: $source -> $target");

    die("upload: $target is not writable.");
  }

  Rex::Commands::profiler()->end("upload: $source -> $target");
}

sub download {
  my ( $self, $source, $target ) = @_;

  Rex::Commands::profiler()->start("download: $source -> $target");

  if ( $^O =~ m/^MSWin/ ) {

    # fix for: #271
    my $ssh  = Rex::is_ssh();
    my $sftp = $ssh->sftp();
    eval {
      my $fh = $sftp->open($source) or die($!);
      open( my $out, ">", $target ) or die($!);
      binmode $out;
      print $out $_ while (<$fh>);
      close $out;
      close $fh;
      1;
    } or do {
      Rex::Commands::profiler()->end("download: $source -> $target");
      die( $ssh->error );
    };
  }
  else {
    my $ssh = Rex::is_ssh();
    if ( !$ssh->scp_get( $source, $target ) ) {
      Rex::Commands::profiler()->end("download: $source -> $target");
      die( $ssh->error );
    }
  }

  Rex::Commands::profiler()->end("download: $source -> $target");
}

1;
