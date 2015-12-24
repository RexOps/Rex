#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Gather - Hardware and Information gathering

=head1 DESCRIPTION

With this module you can gather hardware and software information.

All these functions will not be reported. These functions don't modify anything.

=head1 SYNOPSIS

 operating_system_is("SuSE");


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Gather;

use strict;
use warnings;

# VERSION

use Data::Dumper;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Hardware::Network;
use Rex::Hardware::Memory;
use Rex::Helper::System;
use Rex::Commands;

require Rex::Exporter;
use base qw(Rex::Exporter);

use vars qw(@EXPORT);

@EXPORT = qw(operating_system_is network_interfaces memory
  get_operating_system operating_system operating_system_version operating_system_release
  is_freebsd is_netbsd is_openbsd is_redhat is_linux is_bsd is_solaris is_suse is_debian is_mageia is_windows is_alt is_openwrt is_gentoo is_fedora is_arch
  get_system_information dump_system_information);

=head2 get_operating_system

Will return the current operating system name.

 task "get-os", "server01", sub {
   say get_operating_system();
 };

Aliased by operating_system().

=cut

sub get_operating_system {

  my $operatingsystem = Rex::Hardware::Host->get_operating_system();

  return $operatingsystem || "unknown";

}

=head2 operating_system

Alias for get_operating_system()

=cut

sub operating_system {
  return get_operating_system();
}

=head2 get_system_information

Will return a hash of all system information. These Information will be also used by the template function.

=cut

sub get_system_information {
  return Rex::Helper::System::info();
}

=head2 dump_system_information

This function dumps all known system information on stdout.

=cut

sub dump_system_information {
  my ($info) = @_;
  my %sys_info = get_system_information();

  inspect( \%sys_info,
    { prepend_key => '$', key_value_sep => " = ", no_root => 1 } );
}

=head2 operating_system_is($string)

Will return 1 if the operating system is $string.

 task "is_it_suse", "server01", sub {
   if( operating_system_is("SuSE") ) {
     say "This is a SuSE system.";
   }
 };

=cut

sub operating_system_is {

  my ($os) = @_;

  my $operatingsystem = Rex::Hardware::Host->get_operating_system();

  if ( $operatingsystem eq $os ) {
    return 1;
  }

  return 0;

}

=head2 operating_system_version()

Will return the os release number as an integer. For example, it will convert 5.10 to 510, 10.04 to 1004 or 6.0.3 to 603.

 task "prepare", "server01", sub {
   if( operating_system_version() >= 510 ) {
     say "OS Release is higher or equal to 510";
   }
 };

=cut

sub operating_system_version {

  my ($os) = @_;

  my $operatingsystemrelease = operating_system_release();

  $operatingsystemrelease =~ s/[\.,]//g;

  return $operatingsystemrelease;

}

=head2 operating_system_release()

Will return the os release number as is.

=cut

sub operating_system_release {
  my ($os) = @_;
  return Rex::Hardware::Host->get_operating_system_version();
}

=head2 network_interfaces

Return an HashRef of all the networkinterfaces and their configuration.

 task "get_network_information", "server01", sub {
   my $net_info = network_interfaces();
 };

You can iterate over the devices as follow

 my $net_info = network_interfaces();
 for my $dev ( keys %{ $net_info } ) {
   say "$dev has the ip: " . $net_info->{$dev}->{"ip"} . " and the netmask: " . $net_info->{$dev}->{"netmask"};
 }

=cut

sub network_interfaces {

  my $net = Rex::Hardware::Network->get();

  return $net->{"networkconfiguration"};

}

=head2 memory

Return an HashRef of all memory information.

 task "get_memory_information", "server01", sub {
   my $memory = memory();

   say "Total:  " . $memory->{"total"};
   say "Free:   " . $memory->{"free"};
   say "Used:   " . $memory->{"used"};
   say "Cached:  " . $memory->{"cached"};
   say "Buffers: " . $memory->{"buffers"};
 };

=cut

sub memory {

  my $mem = Rex::Hardware::Memory->get();

  return $mem;

}

=head2 is_freebsd

Returns true if the target system is a FreeBSD.

 task "foo", "server1", "server2", sub {
   if(is_freebsd) {
     say "This is a freebsd system...";
   }
   else {
     say "This is not a freebsd system...";
   }
 };

=cut

sub is_freebsd {
  my $os = @_ ? shift : get_operating_system();
  if ( $os =~ m/FreeBSD/i ) {
    return 1;
  }
}

=head2 is_redhat

 task "foo", "server1", sub {
   if(is_redhat) {
     # do something on a redhat system (like RHEL, Fedora, CentOS, Scientific Linux
   }
 };

=cut

sub is_redhat {
  my $os = @_ ? shift : get_operating_system();

  my @redhat_clones = (
    "Fedora",                      "Redhat",
    "CentOS",                      "Scientific",
    "RedHatEnterpriseServer",      "RedHatEnterpriseES",
    "RedHatEnterpriseWorkstation", "RedHatEnterpriseWS",
    "Amazon",                      "ROSAEnterpriseServer",
    "CloudLinuxServer",
  );

  if ( grep { /$os/i } @redhat_clones ) {
    return 1;
  }
}

=head2 is_fedora

 task "foo", "server1", sub {
   if(is_fedora) {
     # do something on a fedora system
   }
 };

=cut

sub is_fedora {
  my $os = @_ ? shift : get_operating_system();

  my @fedora_clones = ("Fedora");

  if ( grep { /$os/i } @fedora_clones ) {
    return 1;
  }
}

=head2 is_suse

 task "foo", "server1", sub {
   if(is_suse) {
     # do something on a suse system
   }
 };

=cut

sub is_suse {
  my $os = @_ ? shift : get_operating_system();

  my @suse_clones = ( "OpenSuSE", "SuSE", "openSUSE project" );

  if ( grep { /$os/i } @suse_clones ) {
    return 1;
  }
}

=head2 is_mageia

 task "foo", "server1", sub {
   if(is_mageia) {
     # do something on a mageia system (or other Mandriva followers)
   }
 };

=cut

sub is_mageia {
  my $os = @_ ? shift : get_operating_system();

  my @mdv_clones = ( "Mageia", "ROSADesktopFresh" );

  if ( grep { /$os/i } @mdv_clones ) {
    return 1;
  }
}

=head2 is_debian

 task "foo", "server1", sub {
   if(is_debian) {
     # do something on a debian system
   }
 };

=cut

sub is_debian {
  my $os = @_ ? shift : get_operating_system();

  my @debian_clones = ( "Debian", "Ubuntu", "LinuxMint", "Raspbian" );

  if ( grep { /$os/i } @debian_clones ) {
    return 1;
  }
}

=head2 is_alt

 task "foo", "server1", sub {
   if(is_alt) {
     # do something on a ALT Linux system
   }
 };

=cut

sub is_alt {
  my $os = @_ ? shift : get_operating_system();

  my @alt_clones = ("ALT");

  if ( grep { /$os/i } @alt_clones ) {
    return 1;
  }
}

=head2 is_netbsd

Returns true if the target system is a NetBSD.

 task "foo", "server1", "server2", sub {
   if(is_netbsd) {
     say "This is a netbsd system...";
   }
   else {
     say "This is not a netbsd system...";
   }
 };

=cut

sub is_netbsd {
  my $os = @_ ? shift : get_operating_system();
  if ( $os =~ m/NetBSD/i ) {
    return 1;
  }
}

=head2 is_openbsd

Returns true if the target system is an OpenBSD.

 task "foo", "server1", "server2", sub {
   if(is_openbsd) {
     say "This is an openbsd system...";
   }
   else {
     say "This is not an openbsd system...";
   }
 };

=cut

sub is_openbsd {
  my $os = @_ ? shift : get_operating_system();
  if ( $os =~ m/OpenBSD/i ) {
    return 1;
  }
}

=head2 is_linux

Returns true if the target system is a Linux System.

 task "prepare", "server1", "server2", sub {
   if(is_linux) {
    say "This is a linux system...";
   }
   else {
    say "This is not a linux system...";
   }
 };

=cut

sub is_linux {

  my $host = Rex::Hardware::Host->get();
  if ( exists $host->{kernelname}
    && $host->{kernelname}
    && $host->{kernelname} =~ m/Linux/ )
  {
    return 1;
  }
}

=head2 is_bsd

Returns true if the target system is a BSD System.

 task "prepare", "server1", "server2", sub {
   if(is_bsd) {
    say "This is a BSD system...";
   }
   else {
    say "This is not a BSD system...";
   }
 };

=cut

sub is_bsd {

  my $host = Rex::Hardware::Host->get();
  if ( $host->{"kernelname"} =~ m/BSD/ ) {
    return 1;
  }
}

=head2 is_solaris

Returns true if the target system is a Solaris System.

 task "prepare", "server1", "server2", sub {
   if(is_solaris) {
    say "This is a Solaris system...";
   }
   else {
    say "This is not a Solaris system...";
   }
 };

=cut

sub is_solaris {

  my $host = Rex::Hardware::Host->get();
  if ( exists $host->{kernelname}
    && $host->{kernelname}
    && $host->{"kernelname"} =~ m/SunOS/ )
  {
    return 1;
  }
}

=head2 is_windows

Returns true if the target system is a Windows System.

=cut

sub is_windows {

  my $host = Rex::Hardware::Host->get();
  if ( $host->{"operatingsystem"} =~ m/^MSWin/
    || $host->{operatingsystem} eq "Windows" )
  {
    return 1;
  }

}

=head2 is_openwrt

Returns true if the target system is an OpenWrt System.

=cut

sub is_openwrt {
  my $os = get_operating_system();
  if ( $os =~ m/OpenWrt/i ) {
    return 1;
  }

}

=head2 is_gentoo

Returns true if the target system is a Gentoo System.

=cut

sub is_gentoo {
  my $os = get_operating_system();
  if ( $os =~ m/Gentoo/i ) {
    return 1;
  }

}

=head2 is_arch

 task "foo", "server1", sub {
   if(is_arch) {
     # do something on a arch system
   }
 };

=cut

sub is_arch {
  my $os = @_ ? shift : get_operating_system();

  my @arch_clones = ( "Arch", "Manjaro", "Antergos" );

  if ( grep { /$os/i } @arch_clones ) {
    return 1;
  }
}

1;
