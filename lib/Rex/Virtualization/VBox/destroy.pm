#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::VBox::destroy;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("destroying domain: $dom");

  unless ($dom) {
    die("VM $dom not found.");
  }

  i_run "VBoxManage controlvm \"$dom\" poweroff", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error destroying vm $dom");
  }

}

1;
