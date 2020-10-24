#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::images;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @domains;

  Rex::Logger::debug("Getting docker images");

  my @images =
    i_run "docker images --format \"{{.Repository}}:{{.Tag}}:{{.ID}}\"",
    fail_ok => 1;

  my @ret = ();
  for my $line (@images) {
    my ( $image, $tag, $id ) = split( /:/, $line );
    push(
      @ret,
      {
        tag  => $tag,
        name => $image,
        id   => $id,
      }
    );
  }

  return \@ret;
}

1;
