#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Hardware - Base Class for hardware / information gathering

=head1 DESCRIPTION

This module is the base class for hardware/information gathering.

=head1 SYNOPSIS

 use Rex::Hardware;
 
 my %host_info = Rex::Hardware->get(qw/ Host /);
 my %all_info  = Rex::Hardware->get(qw/ All /);

=head1 CLASS METHODS

=cut

package Rex::Hardware;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;

require Rex::Args;

=head2 get(@modules)

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

=item VirtInfo

=back

=cut

my %HW_PROVIDER;

sub register_hardware_provider {
  my ( $class, $service_name, $service_class ) = @_;
  $HW_PROVIDER{"\L$service_name"} = $service_class;
  return 1;
}

sub get {
  my ( $class, @modules ) = @_;

  my %hardware_information;

  if ( "all" eq "\L$modules[0]" ) {

    @modules = qw(Host Kernel Memory Network Swap VirtInfo);
    push( @modules, keys(%HW_PROVIDER) );

  }

  for my $mod_string (@modules) {

    Rex::Commands::profiler()->start("hardware: $mod_string");

    my $mod = "Rex::Hardware::$mod_string";
    if ( exists $HW_PROVIDER{$mod_string} ) {
      $mod = $HW_PROVIDER{$mod_string};
    }

    Rex::Logger::debug("Loading $mod");
    eval "use $mod";

    if ($@) {
      Rex::Logger::info("$mod not found.");
      Rex::Logger::debug("$@");
      next;
    }

    $hardware_information{$mod_string} = $mod->get();

    Rex::Commands::profiler()->end("hardware: $mod_string");

  }

  return %hardware_information;
}

1;
