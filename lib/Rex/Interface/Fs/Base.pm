#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs::Base;

use strict;
use warnings;

# VERSION

use Rex::Interface::Exec;
use Rex::Helper::File::Spec;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub ls          { die("Must be implemented by Interface Class"); }
sub unlink      { die("Must be implemented by Interface Class"); }
sub mkdir       { die("Must be implemented by Interface Class"); }
sub glob        { die("Must be implemented by Interface Class"); }
sub rename      { die("Must be implemented by Interface Class"); }
sub stat        { die("Must be implemented by Interface Class"); }
sub readlink    { die("Must be implemented by Interface Class"); }
sub is_file     { die("Must be implemented by Interface Class"); }
sub is_dir      { die("Must be implemented by Interface Class"); }
sub is_readable { die("Must be implemented by Interface Class"); }
sub is_writable { die("Must be implemented by Interface Class"); }
sub upload      { die("Must be implemented by Interface Class"); }
sub download    { die("Must be implemented by Interface Class"); }

sub chksum {
  my ( $self, $file ) = @_;

  my $chksum;
  eval { $chksum = $self->md5($file); };

  return $chksum;
}

sub md5 {
  my ( $self, $file ) = @_;

  if ( $self->is_file($file) ) {
    Rex::Logger::debug("Calculating checksum (MD5) of $file");

    my $command =
      ( $^O =~ m/^MSWin/i && Rex::is_local() )
      ? qq(perl -MDigest::MD5 -e "open my \$fh, '<', \$ARGV[0] or die 'Cannot open ' . \$ARGV[0]; binmode \$fh; print Digest::MD5->new->addfile(\$fh)->hexdigest;" "$file")
      : qq(perl -MDigest::MD5 -e 'open my \$fh, "<", \$ARGV[0] or die "Cannot open " . \$ARGV[0]; binmode \$fh; print Digest::MD5->new->addfile(\$fh)->hexdigest;' '$file');

    my $md5 = $self->_exec($command);

    unless ( $? == 0 ) {

      my $os = $self->_exec("uname -s");
      if ( $os =~ /bsd/i ) {
        $md5 = $self->_exec("/sbin/md5 -q '$file'");
      }
      else {
        ($md5) = split( /\s/, $self->_exec("md5sum '$file'") );
      }

      if ( !$md5 ) {
        my $message = "Unable to get MD5 checksum of $file: $!";
        Rex::Logger::info($message);
        die($message);
      }
    }

    chomp $md5;

    Rex::Logger::debug("MD5 checksum of $file: $md5");

    return $md5;
  }
  else {
    my $message = "File not found: $file";
    Rex::Logger::debug($message);
    die($message);
  }
}

sub is_symlink {
  my ( $self, $path ) = @_;
  ($path) = $self->_normalize_path($path);

  $self->_exec("/bin/sh -c '[ -L \"$path\" ]'");
  my $ret = $?;

  if ( $ret == 0 ) { return 1; }
}

sub ln {
  my ( $self, $from, $to ) = @_;

  Rex::Logger::debug("Symlinking files: $to -> $from");
  ($from) = $self->_normalize_path($from);
  ($to)   = $self->_normalize_path($to);

  my $exec = Rex::Interface::Exec->create;
  $exec->exec("ln -snf $from $to");

  if ( $? == 0 ) { return 1; }

  die "Error creating symlink. ($from -> $to)" if ( Rex::Config->get_autodie );
}

sub rmdir {
  my ( $self, @dirs ) = @_;

  @dirs = $self->_normalize_path(@dirs);

  Rex::Logger::debug( "Removing directories: " . join( ", ", @dirs ) );
  my $exec = Rex::Interface::Exec->create;
  $exec->exec( "/bin/rm -rf " . join( " ", @dirs ) );

  if ( $? == 0 ) { return 1; }

  die( "Error removing directory: " . join( ", ", @dirs ) )
    if ( Rex::Config->get_autodie );
}

sub chown {
  my ( $self, $user, $file, @opts ) = @_;
  my $options = {@opts};
  ($file) = $self->_normalize_path($file);

  my $recursive = "";
  if ( exists $options->{"recursive"} && $options->{"recursive"} == 1 ) {
    $recursive = " -R ";
  }

  my $exec = Rex::Interface::Exec->create;

  if ( $exec->can_run( ['chown'] ) ) {
    $exec->exec("chown $recursive $user $file");

    if ( $? == 0 ) { return 1; }

    die("Error running chown $recursive $user $file")
      if ( Rex::Config->get_autodie );
  }
  else {
    Rex::Logger::debug("Can't find `chown`.");
    return 1; # fake success for windows
  }
}

sub chgrp {
  my ( $self, $group, $file, @opts ) = @_;
  my $options = {@opts};
  ($file) = $self->_normalize_path($file);

  my $recursive = "";
  if ( exists $options->{"recursive"} && $options->{"recursive"} == 1 ) {
    $recursive = " -R ";
  }

  my $exec = Rex::Interface::Exec->create;

  if ( $exec->can_run( ['chgrp'] ) ) {
    $exec->exec("chgrp $recursive $group $file");

    if ( $? == 0 ) { return 1; }

    die("Error running chgrp $recursive $group $file")
      if ( Rex::Config->get_autodie );
  }
  else {
    Rex::Logger::debug("Can't find `chgrp`.");
    return 1; # fake success for windows
  }
}

sub chmod {
  my ( $self, $mode, $file, @opts ) = @_;
  my $options = {@opts};
  ($file) = $self->_normalize_path($file);

  my $recursive = "";
  if ( exists $options->{"recursive"} && $options->{"recursive"} == 1 ) {
    $recursive = " -R ";
  }

  my $exec = Rex::Interface::Exec->create;

  if ( $exec->can_run( ['chmod'] ) ) {
    $exec->exec("chmod $recursive $mode $file");

    if ( $? == 0 ) { return 1; }

    die("Error running chmod $recursive $mode $file")
      if ( Rex::Config->get_autodie );
  }
  else {
    Rex::Logger::debug("Can't find `chmod`.");
    return 1; # fake success for windows
  }
}

sub cp {
  my ( $self, $source, $dest ) = @_;
  ($source) = $self->_normalize_path($source);
  ($dest)   = $self->_normalize_path($dest);

  my $exec = Rex::Interface::Exec->create;
  $exec->exec("cp -R $source $dest");

  if ( $? == 0 ) { return 1; }

  die("Error copying $source -> $dest") if ( Rex::Config->get_autodie );
}

sub _normalize_path {
  my ( $self, @dirs ) = @_;

  my @ret;
  for my $d (@dirs) {
    my @t;
    if (Rex::is_ssh) {
      @t = Rex::Helper::File::Spec->splitdir($d);
    }
    else {
      @t = Rex::Helper::File::Spec->splitdir($d);
    }
    push( @ret,
      Rex::Helper::File::Spec->catfile( map { $self->_quotepath($_) } @t ) );
  }

  #  for (@dirs) {
  #    s/ /\\ /g;
  #  }

  return @ret;
}

sub _quotepath {
  my ( $self, $p ) = @_;
  $p =~ s/([\@\$\% ])/\\$1/g;

  return $p;
}

sub _exec {
  my ( $self, $cmd ) = @_;
  my ($type) = ( ref($self) =~ m/::([^:]+)$/ );
  my $exec = Rex::Interface::Exec->create($type);
  return $exec->exec($cmd);
}

1;
