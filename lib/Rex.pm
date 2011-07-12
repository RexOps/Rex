#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex - Remote Execution

=head1 DESCRIPTION

(R)?ex is a small script to ease the execution of remote commands. You can write small tasks in a file named I<Rexfile>.

You can find examples and howtos on L<http://rexify.org/>

=head1 GETTING HELP

=over 4

=item * Web Site: L<http://rexify.org/>

=item * IRC: irc.freenode.net #rex

=item * Bug Tracker: L<https://rt.cpan.org/Dist/Display.html?Queue=Rex>

=item * Twitter: L<http://twitter.com/jfried83>

=back

=head1 Dependencies

=over 4

=item *

L<Net::SSH2>

=item *

L<Expect>

Only if you want to use the Rsync module.

=item *

L<DBI>

Only if you want to use the DB module.

=back

=head1 SYNOPSIS

 desc "Show Unix version";
 task "uname", sub {
     say run "uname -a";
 };

 bash# rex -H "server[01..10]" uname

See L<Rex::Commands> for a list of all commands you can use.

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
$VERSION = "0.9.99.0";


sub push_connection {
   push @CONNECTION_STACK, $_[0];
}

sub pop_connection {
   pop @CONNECTION_STACK;
   Rex::Logger::debug("Connections in queue: " . scalar(@CONNECTION_STACK));
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
