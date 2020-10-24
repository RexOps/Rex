#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Notify - Notify a resource to execute.

=head1 DESCRIPTION

This module exports the notify() function.

=head1 SYNOPSIS

 notify "run", "extract-archive";
 notify $type, $resource_name;

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Notify;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(notify);

=head2 notify($resource_type, $resource_name)

This function will notify the given $resource_name of the given $resource_type to execute.

=cut

sub notify {
  my ( $resource_type, $resource_name ) = @_;
  my $notify = Rex::get_current_connection()->{notify};
  $notify->run(
    type => $resource_type,
    name => $resource_name,
  );
}

1;
