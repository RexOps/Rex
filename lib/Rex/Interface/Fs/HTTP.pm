#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Fs::HTTP;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Commands;
use Rex::Interface::Exec;
use Rex::Interface::Fs::Base;
use Data::Dumper;

BEGIN {
  use Rex::Require;
  MIME::Base64->use;
}
use base qw(Rex::Interface::Fs::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub ls {
  my ( $self, $path ) = @_;

  my $resp = connection->post( "/fs/ls", { path => $path } );
  if ( $resp->{ok} ) {
    return @{ $resp->{ls} };
  }
}

sub is_dir {
  my ( $self, $path ) = @_;
  my $resp = connection->post( "/fs/is_dir", { path => $path } );
  return $resp->{ok};
}

sub is_file {
  my ( $self, $file ) = @_;
  my $resp = connection->post( "/fs/is_file", { path => $file } );
  return $resp->{ok};
}

sub unlink {
  my ( $self, @files ) = @_;

  my $ok = 0;
  for my $file (@files) {
    my $resp = connection->post( "/fs/unlink", { path => $file } );
    $ok = $resp->{ok};
  }

  return $ok;
}

sub mkdir {
  my ( $self, $dir ) = @_;
  my $resp = connection->post( "/fs/mkdir", { path => $dir } );
  return $resp->{ok};
}

sub stat {
  my ( $self, $file ) = @_;
  my $resp = connection->post( "/fs/stat", { path => $file } );
  if ( $resp->{ok} ) {
    return %{ $resp->{stat} };
  }

  return undef;
}

sub is_readable {
  my ( $self, $file ) = @_;
  my $resp = connection->post( "/fs/is_readable", { path => $file } );
  return $resp->{ok};
}

sub is_writable {
  my ( $self, $file ) = @_;
  my $resp = connection->post( "/fs/is_writable", { path => $file } );
  return $resp->{ok};
}

sub readlink {
  my ( $self, $file ) = @_;
  my $resp = connection->post( "/fs/readlink", { path => $file } );
  if ( $resp->{ok} ) {
    return $resp->{link};
  }
}

sub rename {
  my ( $self, $old, $new ) = @_;
  my $resp = connection->post( "/fs/rename", { old => $old, new => $new } );
  return $resp->{ok};
}

sub glob {
  my ( $self, $glob ) = @_;
  my $resp = connection->post( "/fs/glob", { glob => $glob } );
  if ( $resp->{ok} ) {
    return @{ $resp->{glob} };
  }
}

sub upload {
  my ( $self, $source, $target ) = @_;

  my $resp = connection->upload( [ content => [$source], path => $target ] );
  return $resp->{ok};
}

sub download {
  my ( $self, $source, $target ) = @_;

  my $resp = connection->post( "/fs/download", { path => $source } );
  if ( $resp->{ok} ) {
    open( my $fh, ">", $target ) or die($!);
    print $fh decode_base64( $resp->{content} );
    close($fh);

    return 1;
  }

  return 0;
}

sub ln {
  my ( $self, $from, $to ) = @_;

  Rex::Logger::debug("Symlinking files: $to -> $from");
  my $resp = connection->post( "/fs/ln", { from => $from, to => $to } );
  return $resp->{ok};
}

sub rmdir {
  my ( $self, @dirs ) = @_;

  Rex::Logger::debug( "Removing directories: " . join( ", ", @dirs ) );
  my $ok = 0;
  for my $dir (@dirs) {
    my $resp = connection->post( "/fs/rmdir", { path => $dir } );
    $ok = $resp->{ok};
  }

  return $ok;
}

sub chown {
  my ( $self, $user, $file, @opts ) = @_;

  my $resp = connection->post(
    "/fs/chown",
    {
      user    => $user,
      path    => $file,
      options => {@opts},
    }
  );

  return $resp->{ok};
}

sub chgrp {
  my ( $self, $group, $file, @opts ) = @_;

  my $resp = connection->post(
    "/fs/chgrp",
    {
      group   => $group,
      path    => $file,
      options => {@opts},
    }
  );

  return $resp->{ok};
}

sub chmod {
  my ( $self, $mode, $file, @opts ) = @_;

  my $resp = connection->post(
    "/fs/chmod",
    {
      mode    => $mode,
      path    => $file,
      options => {@opts},
    }
  );

  return $resp->{ok};
}

sub cp {
  my ( $self, $source, $dest ) = @_;

  my $resp = connection->post(
    "/fs/cp",
    {
      source => $source,
      dest   => $dest,
    }
  );

  return $resp->{ok};
}

1;
