#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Tail

=head1 DESCRIPTION

With this module you can tail a file

=head1 SYNOPSIS

 tail "/var/log/syslog";


=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Tail;

use strict;
use warnings;

require Exporter;
use Data::Dumper;
use Rex::Helper::SSH2;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(tail);

=item tail($file)

This function will tail the given file.

 task "syslog", "server01", sub {
    tail "/var/log/syslog";
 };

=cut

sub tail {
   my $file = shift;

   Rex::Logger::debug("Tailing: $file");

   if(my $ssh = Rex::is_ssh()) {
      net_ssh2_exec_output($ssh, "tail -f $file", sub {
         my ($data) = @_;
         print "$data";
      });
   } else {
      system("tail -f $file");
   }

}

=back

=cut

1;
