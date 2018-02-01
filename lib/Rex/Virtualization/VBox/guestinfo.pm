#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::guestinfo;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Virtualization::VBox::status;

sub execute {
  my ( $class, $vmname ) = @_;

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting info of guest: $vmname");

  my $status = Rex::Virtualization::VBox::status->execute($vmname);
  if ( $status eq "stopped" ) {
    Rex::Logger::debug("VM is not running, no guestinfo available.");
    return {};
  }

  # getting info of network interfaces
  my $netcount = _get_property( $vmname, "/VirtualBox/GuestInfo/Net/Count" );

  my @netinfo;
  for ( my $i = 0 ; $i < $netcount ; $i++ ) {

    my $ip  = _get_property( $vmname, "/VirtualBox/GuestInfo/Net/$i/V4/IP" );
    my $mac = _get_property( $vmname, "/VirtualBox/GuestInfo/Net/$i/MAC" );
    my $netmask =
      _get_property( $vmname, "/VirtualBox/GuestInfo/Net/$i/V4/Netmask" );
    my $status =
      _get_property( $vmname, "/VirtualBox/GuestInfo/Net/$i/Status" );
    my $broadcast =
      _get_property( $vmname, "/VirtualBox/GuestInfo/Net/$i/V4/Broadcast" );

    push(
      @netinfo,
      {
        ip        => $ip,
        mac       => $mac,
        netmask   => $netmask,
        status    => $status,
        broadcast => $broadcast,
      }
    );
  }

  if ( $? != 0 ) {
    die("Error running VBoxManage guestproperty $vmname");
  }

  return { net => \@netinfo, };
}

sub _get_property {
  my ( $vmname, $prop ) = @_;

  my ($got_value) = (0);

  while ( $got_value != 1 ) {
    my @a_tmp = i_run "VBoxManage guestproperty get \"$vmname\" \"$prop\"",
      fail_ok => 1;

    if ( $a_tmp[0] =~ m/No value set/ ) {
      sleep 1;
      next;
    }

    $got_value = 1;

    my ($return) = ( $a_tmp[0] =~ m/Value: (.*)/ );
    return $return;
  }

}

1;
