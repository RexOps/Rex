#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::start;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1, %opt ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");

  Rex::Logger::debug("Starting vm: $arg1");

  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug("starting domain: $dom");

  unless ($dom) {
    die("VM $dom not found.");
  }

  my $output = i_run "virsh -c $uri start '$dom' 2>&1", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error starting vm $dom\nError: $output");
  }

}

1;
