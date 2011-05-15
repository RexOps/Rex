#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex

=head1 DESCRIPTION

This is the main Package.

=head1 SYNOPSIS

 Rex->is_ssh()
 Rex->get_current_connection()

=head1 CLASS METHODS

=over 4

=cut


package Rex;

use strict;
use warnings;

use Rex::Logger;

require Exporter;
use base qw(Exporter);

use vars qw(@EXPORT $VERSION @CONNECTION_STACK);

@EXPORT = qw($VERSION);
$VERSION = "0.4.2";


sub push_connection {
   push @CONNECTION_STACK, $_[0];
}

sub pop_connection {
   pop @CONNECTION_STACK;
}

=item get_current_connection

Returns the current connection as a hashRef.

=over 4

=item server

The server name

=item ssh

1 if it is a ssh connection, 0 if not.

=back

=cut

sub get_current_connection {
   $CONNECTION_STACK[-1];
}

=item is_ssh

Returns 1 if the current connection is a ssh connection. 0 if not.

=cut

sub is_ssh {
   if($CONNECTION_STACK[-1]) {
      return $CONNECTION_STACK[-1]->{"ssh"};
   }

   return 0;
}

=back

=cut

1;
