#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::info;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
  my ( $class, $vmname ) = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting info of domain: $vmname");

  my $xml;

  my @dominfo = i_run "VBoxManage showvminfo \"$vmname\" --machinereadable",
    fail_ok => 1;

  if ( $? != 0 ) {
    die("Error running VBoxManage showvminfo $vmname");
  }

  my %ret = ();
  my ( $k, $v );

  for my $line (@dominfo) {
    ( $k, $v ) = split( /=/, $line );
    $k =~ s/^"|"$//g;
    $v =~ s/^"|"$//g;
    $ret{$k} = $v;
  }

  return \%ret;
}

1;
