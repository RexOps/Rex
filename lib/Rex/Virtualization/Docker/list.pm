#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::list;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @domains;

  Rex::Logger::debug("Getting docker list by ps");

  if ( $arg1 eq "all" ) {
    @domains =
      i_run
      "docker ps -a --format \"{{.ID}}|{{.Image}}|{{.Command}}|{{.CreatedAt}}|{{.Status}}|{{.Names}}\"",
      fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running docker ps");
    }
  }
  elsif ( $arg1 eq "running" ) {
    @domains =
      i_run
      "docker ps --format \"{{.ID}}|{{.Image}}|{{.Command}}|{{.CreatedAt}}|{{.Status}}|{{.Names}}\"",
      fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running docker ps");
    }
  }
  else {
    return;
  }

  my @ret = ();
  for my $line (@domains) {
    my ( $id, $images, $cmd, $created, $status, $comment ) =
      split( /\|/, $line );
    $cmd =~ s/^"|"$//gms;
    push(
      @ret,
      {
        comment => $comment,
        name    => $comment,
        id      => $id,
        images  => $images,
        command => $cmd,
        created => $created,
        status  => $status,
      }
    );
  }

  return \@ret;
}

1;
