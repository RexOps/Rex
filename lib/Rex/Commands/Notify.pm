#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Notify - Notify a resource to execute.

=head1 DESCRIPTION

This module exports the notify() function.

=head1 SYNOPSIS

 notify "run", "extract-archive";
 notify $type, $resource_name;

=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Notify;

use strict;
use warnings;

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(notify);

=item notify($resource_type, $resource_name)

This function will notify the given $resource_name of the given $resource_type to execute.

=cut

sub notify {
   my ($resource_type, $resource_name) = @_;
   my $notify = Rex::get_current_connection()->{notify};
   $notify->run(
      type => $resource_type,
      name => $resource_name,
   );
}

=back

=cut

1;
