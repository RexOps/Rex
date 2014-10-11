#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::info;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;
use Rex::Virtualization::LibVirt::dumpxml;

use Data::Dumper;

sub execute {
  my ( $class, $vmname ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  unless ($vmname) {
    die("You have to define the vm name!");
  }

  Rex::Logger::debug("Getting info of domain: $vmname");

  my $xml;

  my @dominfo = i_run "virsh -c $uri dominfo $vmname";

  if ( $? != 0 ) {
    die("Error running virsh dominfo $vmname");
  }

  my %ret = ();
  my ( $k, $v );

  for my $line (@dominfo) {
    ( $k, $v ) = split( /:\s+/, $line );
    $ret{$k} = $v;
  }

  my $xml_ref = Rex::Virtualization::LibVirt::dumpxml->execute($vmname);
  if ( $xml_ref && exists $xml_ref->{devices}->{serial} ) {
    my ($agent_serial) = grep {
           exists $_->{type}
        && $_->{type} eq "tcp"
        && $_->{target}->{port} == 1
    } @{ $xml_ref->{devices}->{serial} };

    $ret{has_kvm_agent_on_port} = $agent_serial->{source}->{service};
  }

  return \%ret;
}

1;
