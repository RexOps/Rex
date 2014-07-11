#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::shutdown;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("shutdown domain: $dom");

  unless ($dom) {
    die("VM $dom not found.");
  }

  i_run "VBoxManage controlvm \"$dom\" acpipowerbutton";
  if ( $? != 0 ) {
    die("Error shutdown vm $dom");
  }

}

1;
