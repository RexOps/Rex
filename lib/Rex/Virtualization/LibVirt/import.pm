#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::import;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use File::Basename;
use Rex::Virtualization::LibVirt::create;

#
# %opt = (cpus => 2, memory => 512)
#
sub execute {
  my ( $class, $arg1, %opt ) = @_;

  unless ($arg1) {
    die("You have to define the vm name!");
  }

  my $dom = $arg1;
  Rex::Logger::debug( "importing: $dom -> " . $opt{file} );

  my $dir  = dirname $opt{file};
  my $file = "storage/" . basename $opt{file};
#  mkdir 

  my @vmdk = grep { m/\.vmdk$/ } i_run "tar -C $dir -v -x -z -f $opt{file}";
  i_run "qemu-img convert -O qcow2 $vmdk[0] $vmdk[0].qcow2";

  Rex::Virtualization::LibVirt::create(
    $dom,
    storage => [
      {
        file => ""
      },
    ],
  );

  if ( $? != 0 ) {
    die("Error importing VM $opt{file}");
  }
}

1;
