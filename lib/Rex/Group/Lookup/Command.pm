#
# (c) xiahou feng <fanyeren@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Group::Lookup::Command - read hostnames from a command.

=head1 DESCRIPTION

With this module you can define hostgroups out of a command.

=head1 SYNOPSIS

 use Rex::Group::Lookup::Command;
 
 group "dbserver"  => lookup_command("cat ip.list | grep -v -E '^#'");
 
 rex xxxx                            # dbserver

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Group::Lookup::Command;

use strict;
use warnings;

require Rex::Exporter;
use Rex -base;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(lookup_command);

sub lookup_command {
  my $command = shift;

  my $command_to_exec;
  my @content;

  if ( defined $command && $command ) {
    $command_to_exec = $command;
    Rex::Logger::info("Command: $command");
  }

  unless ( defined $command_to_exec && $command_to_exec ) {
    Rex::Logger::info("You must give a valid command.");
    return @content;
  }

  eval {
    open( my $command_rt, "$command_to_exec |" ) or die($!);
    @content = grep { !/^\s*$|^#/ } <$command_rt>;
    close($command_rt);

    chomp @content;
  };
  Rex::Logger::info("You must give a valid command.") unless $#content;
  return @content;
}

=back

=cut

1;
