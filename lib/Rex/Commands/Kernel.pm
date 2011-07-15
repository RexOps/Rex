#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Kernel - Load/Unload Kernel Modules

=head1 DESCRIPTION

With this module you can load and unload kernel modules.

=head1 SYNOPSIS

 kmod load => "ipmi_si";
 
 kmod unload => "ipmi_si";

=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Kernel;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use Data::Dumper;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(kmod);

=item kmod($action => $module)

This function load or unload a kernel module.

 task "load", sub {
    kmod load => "ipmi_si";
 };

 task "unload", sub {
    kmod unload => "ipmi_si";
 };

=cut

sub kmod {
   my ($action, $module) = @_;

   if($action eq "load") {
      Rex::Logger::debug("Loading Kernel Module: $module");
      run "modprobe $module";
      unless($? == 0) {
         Rex::Logger::info("Error loading Kernel Module: $module");
      }
      else {
         Rex::Logger::debug("Kernel Module $module loaded.");
      }
   }
   elsif($action eq "unload") {
      Rex::Logger::debug("Unloading Kernel Module: $module");
      run "rmmod $module";
      unless($? == 0) {
         Rex::Logger::info("Error unloading Kernel Module: $module");
      }
      else {
         Rex::Logger::debug("Kernel Module $module unloaded.");
      } 
   }
   else {
      Rex::Logger::info("Unknown action $action");
      exit 1;
   }
}

=back

=cut

1;
