#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::User;

use strict;
use warnings;

# VERSION

use Rex::Commands::Gather;
use Rex::Logger;
use Module::Runtime qw(use_module);

sub get {

  my $user_o = "Linux";
  if (is_freebsd) {
    $user_o = "FreeBSD";
  }
  elsif (is_netbsd) {
    $user_o = "NetBSD";
  }
  elsif (is_openbsd) {
    $user_o = "OpenBSD";
  }
  elsif ( operating_system_is("SunOS") ) {
    $user_o = "SunOS";
  }
  elsif (is_openwrt) {
    $user_o = "OpenWrt";
  }

  my $class = "Rex::User::" . $user_o;
  eval { use_module( $class ) }
      or do {

    Rex::Logger::info("OS not supported");
    die("OS not supported");

  };

  return $class->new;

}

1;
