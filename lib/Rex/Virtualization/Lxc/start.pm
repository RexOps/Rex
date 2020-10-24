#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::start;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the container name!");
  }

  my $container_name = $arg1;
  Rex::Logger::debug("starting container $container_name");

  unless ($container_name) {
    die("VM $container_name not found.");
  }

  i_run "lxc-start -d -n \"$container_name\"", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error starting container $container_name");
  }

}

1;
