#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Run - Execute a remote command

=head1 DESCRIPTION

With this module you can run a command.

=head1 SYNOPSIS

 my $output = run "ls -l";


=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Run;

use strict;
use warnings;

require Exporter;
use Data::Dumper;
use Rex;
use Rex::Logger;
use Rex::Helper::SSH2;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(run can_run);

=item run($command)

This function will execute the given command and returns the output.

 task "uptime", "server01", sub {
    say run "uptime";
 };

=cut

sub run {
   my $cmd = shift;

   Rex::Logger::debug("Running command: $cmd");

   my @ret = ();
   my $out;
   if(my $ssh = Rex::is_ssh()) {
      $out = net_ssh2_exec($ssh, "LC_ALL=C " . $cmd);
   } else {
      $out = qx{LC_ALL=C $cmd};
   }

   Rex::Logger::debug($out);

   chomp $out;

   if(wantarray) {
      return split(/\n/, $out);
   }

   return $out;
}

=item can_run($command)

This function checks if a command is in the path or is available.

 task "uptime", sub {
    if(can_run "uptime") {
       say run "uptime";
    }
 };

=cut
sub can_run {
   my $cmd = shift;

   if($cmd =~ m/^\//) {
      if(is_file($cmd)) {
         return 1;
      }
   }
   else {
      run "which $cmd";
      if($? == 0) { return 1; }
   }
}

=back

=cut

1;
