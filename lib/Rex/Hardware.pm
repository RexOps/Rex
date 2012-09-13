#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Hardware - Base Class for hardware / information gathering

=head1 DESCRIPTION

This module is the base class for hardware/information gathering.

=head1 SYNOPSIS

 use Rex::Hardware;
 
 my %host_info = Rex::Hardware->get(qw/ Host /)
 my %all_info  = Rex::Hardware->get(qw/ All /)

=head1 CLASS METHODS

=over 4

=cut



package Rex::Hardware;

use strict;
use warnings;

use Rex::Logger;

require Rex::Args;

=item get(@modules)

Returns a hash with the wanted information.

 task "get-info", "server1", sub {
    %hw_info = Rex::Hardware->get(qw/ Host Network /);
 };

Or if you want to get all information

 task "get-all-info", "server1", sub {
    %hw_info = Rex::Hardware->get(qw/ All /);
 };

Available modules:

=over 4

=item Host

=item Kernel

=item Memory

=item Network

=item Swap

=back

=cut

our %hw_info = ();

sub get {
   my($class, @modules) = @_;

   my %hardware_information;

   if("all" eq "\L$modules[0]") {

      @modules = qw(Host Kernel Memory Network Swap);
   
   }

   for my $mod_string (@modules) {

      if(exists $hw_info{$mod_string} && Rex::Args->is_opt("c")) {
         $hardware_information{$mod_string} = $hw_info{$mod_string};
      }

      else {

         my $mod = "Rex::Hardware::$mod_string";
         Rex::Logger::debug("Loading Rex::Hardware::$mod_string");
         eval "use Rex::Hardware::$mod_string";

         if($@) {
            Rex::Logger::info("Rex::Hardware::$mod_string not found.");
            Rex::Logger::debug("$@");
            next;
         }

         $hardware_information{$mod_string} = $mod->get();

         if(Rex::Args->is_opt("c")) {
            $hw_info{$mod_string} = $hardware_information{$mod_string};
         }

      }

   }

   return %hardware_information;
}

sub reset {
   my ($class) = @_;
   %hw_info = ();
}

sub cache {
   my ($class, $mod) = @_;
   if(exists $hw_info{$mod}) {
      return $hw_info{$mod};
   }
}

=back

=cut

1;
