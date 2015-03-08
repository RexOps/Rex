#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs::OpenSSH;

use strict;
use warnings;

# VERSION

use Fcntl qw(:DEFAULT :mode);
use Rex::Interface::Exec;
use Rex::Interface::Fs::SSH;

BEGIN {
  use Rex::Require;
  Net::SFTP::Foreign::Constants->use(qw(:flags));
}

use base qw(Rex::Interface::Fs::SSH);

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
    my $ls   = $sftp->ls($path);

    for my $entry ( @{$ls} ) {
      push @ret, $entry->{'filename'};
    }
  };
  Rex::Commands::profiler()->end("ls: $path");

  # failed open directory, return undef
  die "Error listing directory content ($path)"
    if ( $@ && Rex::Config->get_autodie );
  if ($@) { return; }

  # return directory content
  return @ret;
}

sub is_dir {
  my ( $self, $path ) = @_;

  Rex::Commands::profiler()->start("is_dir: $path");

  my $sftp = Rex::get_sftp();
  my $attr = $sftp->stat($path);

  Rex::Commands::profiler()->end("is_dir: $path");

  defined $attr ? return S_ISDIR( $attr->perm ) : return 0;
}

sub is_file {
  my ( $self, $file ) = @_;

  Rex::Commands::profiler()->start("is_file: $file");

  my $sftp = Rex::get_sftp();
  my $attr = $sftp->stat($file);

  Rex::Commands::profiler()->end("is_file: $file");

  defined $attr
    ? return ( S_ISREG( $attr->perm )
      || S_ISLNK( $attr->perm )
      || S_ISBLK( $attr->perm )
      || S_ISCHR( $attr->perm )
      || S_ISFIFO( $attr->perm )
      || S_ISSOCK( $attr->perm ) )
    : return 0;
}

sub unlink {
  my ( $self, @files ) = @_;

  my $sftp = Rex::get_sftp();
  for my $file (@files) {
    Rex::Commands::profiler()->start("unlink: $file");
    eval {
      $sftp->remove($file);
      1;
    } or do {
      die "Error unlinking file: $file." if ( Rex::Config->get_autodie );
    };
    Rex::Commands::profiler()->end("unlink: $file");
  }
}

sub stat {
  my ( $self, $file ) = @_;

  Rex::Commands::profiler()->start("stat: $file");

  my $sftp = Rex::get_sftp();
  my $ret  = $sftp->stat($file);

  if ( !$ret ) { return; }

  my %ret = (
    mode  => sprintf( "%04o", $ret->perm & 07777 ),
    size  => $ret->size,
    uid   => $ret->uid,
    gid   => $ret->gid,
    atime => $ret->atime,
    mtime => $ret->mtime,
  );

  Rex::Commands::profiler()->end("stat: $file");

  return %ret;
}

sub upload {
  my ( $self, $source, $target ) = @_;

  Rex::Commands::profiler()->start("upload: $source -> $target");

  my $sftp = Rex::get_sftp();
  unless ( $sftp->put( $source, $target ) ) {
    Rex::Logger::debug("upload: $target is not writable");

    Rex::Commands::profiler()->end("upload: $source -> $target");

    die("upload: $target is not writable.");
  }

  Rex::Commands::profiler()->end("upload: $source -> $target");
}

sub download {
  my ( $self, $source, $target ) = @_;

  Rex::Commands::profiler()->start("download: $source -> $target");

  my $sftp = Rex::get_sftp();
  if ( !$sftp->get( $source, $target ) ) {
    Rex::Commands::profiler()->end("download: $source -> $target");
    die( $sftp->error );
  }

  Rex::Commands::profiler()->end("download: $source -> $target");
}

1;
