#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::info;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;
use JSON::XS;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @dominfo;

  if ( !$arg1 ) {
    die('Must define container ID');
  }

  Rex::Logger::debug("Getting docker info by inspect");

  my $ret = i_run "docker inspect $arg1";
  if ( $? != 0 ) {
    die("Error running docker inspect");
  }

  return decode_json($ret);
}

1;
