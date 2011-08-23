#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Gather - Hardware and Information gathering

=head1 DESCRIPTION

With this module you can gather hardware and software information.

=head1 SYNOPSIS

 operating_system_is("SuSE");


=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Gather;

use strict;
use warnings;

use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Hardware::Network;
use Rex::Hardware::Memory;

require Exporter;
use base qw(Exporter);

use vars qw(@EXPORT);

@EXPORT = qw(operating_system_is network_interfaces memory get_operating_system 
               is_freebsd is_redhat);

=item get_operating_system

Will return the current operating system name.
 
 task "get-os", "server01", sub {
    say get_operating_system();
 };

=cut

sub get_operating_system {

   my $host = Rex::Hardware::Host->get();

   return $host->{"operatingsystem"} || "unknown";

}

=item operating_system_is($string)

Will return 1 if the operating system is $string.
 
 task "is_it_suse", "server01", sub {
    if( operating_system_is("SuSE") ) {
       say "This is a SuSE system.";
    }
 };

=cut

sub operating_system_is {

   my ($os) = @_;

   my $host = Rex::Hardware::Host->get();

   if($host->{"operatingsystem"} eq $os) {
      return 1;
   }

   return 0;

}

=item network_interfaces

Return an HashRef of all the networkinterfaces and their configuration.

 task "get_network_information", "server01", sub {
    my $net_info = network_interfaces();
 };

You can interate over the devices as follow

 my $net_info = network_interfaces();
 for my $dev ( keys %{ $net_info } ) {
    say "$dev has the ip: " . $net_info->{$dev}->{"ip"} . " and the netmask: " . $net_info->{$dev}->{"netmask"};
 }

=cut

sub network_interfaces {
   
   my $net = Rex::Hardware::Network->get();

   return $net->{"networkconfiguration"};

}

=item memory

Return an HashRef of all memory information.

 task "get_memory_information", "server01", sub {
    my $memory = memory();
     
    say "Total:   " . $memory->{"total"};
    say "Free:    " . $memory->{"free"};
    say "Used:    " . $memory->{"used"};
    say "Cached:  " . $memory->{"cached"};
    say "Buffers: " . $memory->{"buffers"};
 };

=cut

sub memory {

   my $mem = Rex::Hardware::Memory->get();

   return $mem;

}

=item is_freebsd

Returns true if the target system is a BSD.

 task "foo", "server1", "server2", sub {
    if(is_freebsd) {
       say "This is a bsd system...";
    }
    else {
       say "This is not a bsd system...";
    }
 };

=cut
sub is_freebsd {
   my $os = get_operating_system();
   if($os =~ m/FreeBSD/i) {
      return 1;
   }
}

=item is_redhat

 task "foo", "server1", sub {
    if(is_redhat) {
       # do something on a redhat system (like RHEL, Fedora, CentOS, Scientific Linux
    }
 };

=cut
sub is_redhat {
   my $os = get_operating_system();

   my @redhat_clones = ("Fedora", "Redhat", "CentOS", "Scientific");

   if(grep { /$os/i } @redhat_clones) {
      return 1;
   }
}


=back

=cut

1;
