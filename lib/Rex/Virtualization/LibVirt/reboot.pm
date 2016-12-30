#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::reboot;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("rebooting domain: $dom");

  unless ($dom) {
    die("VM $dom not found.");
  }

  i_run "virsh -c $uri reboot '$dom'", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error rebooting vm $dom");
  }

}

1;
