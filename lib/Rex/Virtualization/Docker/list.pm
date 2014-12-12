#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::list;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @domains;

  Rex::Logger::debug("Getting docker list by ps");

  if ( $arg1 eq "all" ) {
    @domains = i_run "docker ps -a";
    if ( $? != 0 ) {
      die("Error running docker ps");
    }
  }
  elsif ( $arg1 eq "running" ) {
    @domains = i_run "docker ps";
    if ( $? != 0 ) {
      die("Error running docker ps");
    }
  }
  else {
    return;
  }

  my @ret = ();
  for my $line (@domains) {
    next if $line =~ m/^CONTAINER ID\s/;
    my ( $id, $images, $cmd, $created, $status, $comment ) =
      split( /\s{2,}/, $line );
    push(
      @ret,
      {
        comment => $comment,
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
