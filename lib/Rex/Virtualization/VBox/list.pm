#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::list;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;

use Data::Dumper;

sub execute {
  my ( $class, $arg1, %opt ) = @_;
  my @domains;

  if ( $arg1 eq "all" ) {
    @domains = i_run "VBoxManage list vms", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running VBoxManage list vms");
    }
  }
  elsif ( $arg1 eq "running" ) {
    @domains = i_run "VBoxManage list runningvms", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running VBoxManage runningvms");
    }
  }
  else {
    return;
  }

  my @ret = ();
  for my $line (@domains) {
    my ( $name, $id ) = $line =~ m:^"([^"]+)"\s*\{([^\}]+)\}$:;

    my @status = map { /^VMState="([^"]+)"$/ }
      i_run "VBoxManage showvminfo \"{$id}\" --machinereadable", fail_ok => 1;
    my $status;

    push(
      @ret,
      {
        id     => $id,
        name   => $name,
        status => $status[0],
      }
    );
  }

  return \@ret;

}

1;
