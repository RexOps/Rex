#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Kernel - Load/Unload Kernel Modules

=head1 DESCRIPTION

With this module you can load and unload kernel modules.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 SYNOPSIS

 kmod load => "ipmi_si";
 
 kmod unload => "ipmi_si";

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Kernel;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Commands::Gather;

use Data::Dumper;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(kmod);

=head2 kmod($action => $module)

This function loads or unloads a kernel module.

 task "load", sub {
   kmod load => "ipmi_si";
 };
 
 task "unload", sub {
   kmod unload => "ipmi_si";
 };

If you're using NetBSD or OpenBSD you have to specify the complete path and, if needed the entry function.

 task "load", sub {
   kmod load => "/usr/lkm/ntfs.o";
   kmod load => "/path/to/module.o", entry => "entry_function";
 };

=cut

sub kmod {
  my ( $action, $module, @rest ) = @_;

  my $options = {@_};

  my $os = get_operating_system();

  my $load_command   = "modprobe";
  my $unload_command = "rmmod";

  if ( $os eq "FreeBSD" ) {
    $load_command   = "kldload";
    $unload_command = "kldunload";
  }
  elsif ( $os eq "NetBSD" || $os eq "OpenBSD" ) {
    $load_command   = "modload";
    $unload_command = "modunload";

    if ( $options->{"entry"} ) {
      $load_command .= " -e " . $options->{"entry"};
    }
  }
  elsif ( $os eq "SunOS" ) {
    $load_command = "modload -p ";

    if ( $options->{"exec_file"} ) {
      $load_command .= " -e " . $options->{"exec_file"} . " ";
    }

    $unload_command = sub {
      my @mod_split = split( /\//, $module );
      my $mod       = $mod_split[-1];

      my ($mod_id) = map { /^\s*(\d+)\s+.*$mod/ } i_run "modinfo";
      my $cmd = "modunload -i $mod_id";

      if ( $options->{"exec_file"} ) {
        $cmd .= " -e " . $options->{"exec_file"};
      }

      return $cmd;
    };
  }
  elsif ( $os eq "OpenWrt" ) {
    $load_command = "insmod";
  }

  if ( $action eq "load" ) {
    Rex::Logger::debug("Loading Kernel Module: $module");
    i_run "$load_command $module", fail_ok => 1;
    unless ( $? == 0 ) {
      Rex::Logger::info( "Error loading Kernel Module: $module", "warn" );
      die("Error loading Kernel Module: $module");
    }
    else {
      Rex::Logger::debug("Kernel Module $module loaded.");
    }
  }
  elsif ( $action eq "unload" ) {
    Rex::Logger::debug("Unloading Kernel Module: $module");
    my $unload_command_str = $unload_command;
    if ( ref($unload_command) eq "CODE" ) {
      $unload_command_str = &$unload_command();
    }

    i_run "$unload_command_str $module", fail_ok => 1;
    unless ( $? == 0 ) {
      Rex::Logger::info( "Error unloading Kernel Module: $module", "warn" );
      die("Error unloading Kernel Module: $module");
    }
    else {
      Rex::Logger::debug("Kernel Module $module unloaded.");
    }
  }
  else {
    Rex::Logger::info("Unknown action $action");
    die("Unknown action $action");
  }
}

1;
