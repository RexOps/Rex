#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Run - Run commands, remote or local

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
use Rex::Helper::SSH2;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(run);

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
      $out = net_ssh2_exec($ssh, $cmd);
   } else {
      $out = qx{$cmd};
   }

   Rex::Logger::debug($out);

   chomp $out;

   if(wantarray) {
      return split(/\n/, $out);
   }

   return $out;
}

=back

=cut

1;
