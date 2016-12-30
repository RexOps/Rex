#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::reboot;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the container name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("rebooting container $dom");

  unless ($dom) {
    die("VM $dom not found.");
  }

  i_run "docker restart \"$dom\"", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error rebooting container $dom");
  }

}

1;

