#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs::Local;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Fs::Base;
use base qw(Rex::Interface::Fs::Base);
use Rex::Helper::File::Stat;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub upload {
  my ( $self, $source, $target ) = @_;
  $self->cp( $source, $target );
}

sub download {
  my ( $self, $source, $target ) = @_;
  $self->cp( $source, $target );
}

sub ls {
  my ( $self, $path ) = @_;

  my @ret;

  eval {
    opendir( my $dh, $path ) or die("$path is not a directory");
    while ( my $entry = readdir($dh) ) {
      next if ( $entry =~ /^\.\.?$/ );
      push @ret, $entry;
    }
    closedir($dh);
  };

  # failed open directory, return undef

  die "Error listing directory content ($path)"
    if ( $@ && Rex::Config->get_autodie );
  if ($@) { return; }

  # return directory content
  return @ret;
}

sub rmdir {
  my ( $self, @dirs ) = @_;

  Rex::Logger::debug( "Removing directories: " . join( ", ", @dirs ) );
  my $exec = Rex::Interface::Exec->create;
  if ( $^O =~ m/^MSWin/ ) {
    for (@dirs) {
      s/\//\\/g;
    }
    $exec->exec( "rd /Q /S " . join( " ", @dirs ) );
  }
  else {
    @dirs = $self->_normalize_path(@dirs);
    $exec->exec( "/bin/rm -rf " . join( " ", @dirs ) );
  }

  if ( $? == 0 ) { return 1; }

  die( "Error removing directory: " . join( ", ", @dirs ) )
    if ( Rex::Config->get_autodie );
}

sub is_dir {
  my ( $self, $path ) = @_;
  ( -d $path ) ? return 1 : return undef;
}

sub is_file {
  my ( $self, $file ) = @_;
  ( -f $file || -l $file || -b $file || -c $file || -p $file || -S $file )
    ? return 1
    : return undef;
}

sub unlink {
  my ( $self, @files ) = @_;
  for my $file (@files) {
    if ( CORE::unlink($file) == 0 ) {
      die "Error unlinking file: $file" if ( Rex::Config->get_autodie );
      return 0;
    }
  }

  return 1;
}

sub mkdir {
  my ( $self, $dir ) = @_;
  if ( CORE::mkdir($dir) == 0 ) {
    die "Error creating directory: $dir" if ( Rex::Config->get_autodie );
    return 0;
  }

  return 1;
}

sub stat {
  my ( $self, $file ) = @_;

  if (
    my (
      $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
      $size, $atime, $mtime, $ctime, $blksize, $blocks
    )
    = CORE::stat($file)
    )
  {

    my %ret;

    $ret{'mode'}  = sprintf( "%04o", Rex::Helper::File::Stat->S_IMODE($mode) );
    $ret{'size'}  = $size;
    $ret{'uid'}   = $uid;
    $ret{'gid'}   = $gid;
    $ret{'atime'} = $atime;
    $ret{'mtime'} = $mtime;

    return %ret;
  }

  return undef;
}

sub is_readable {
  my ( $self, $file ) = @_;
  if ( -r $file ) { return 1; }
}

sub is_writable {
  my ( $self, $file ) = @_;
  if ( -w $file ) { return 1; }
}

sub readlink {
  my ( $self, $file ) = @_;
  return CORE::readlink($file);
}

sub rename {
  my ( $self, $old, $new ) = @_;

  my $exec = Rex::Interface::Exec->create;

  if ( $^O =~ m/^MSWin/ ) {
    $old =~ s/\//\\/g;
    $new =~ s/\//\\/g;
    $exec->exec("move \"$old\" \"$new\"");
  }
  else {
    ($old) = $self->_normalize_path($old);
    ($new) = $self->_normalize_path($new);
    $exec->exec("/bin/mv $old $new");
  }

  if ( $? == 0 ) { return 1; }

  die "Error renaming file or directory: $old -> $new"
    if ( Rex::Config->get_autodie );
}

sub glob {
  my ( $self, $glob ) = @_;
  return CORE::glob($glob);
}

1;
