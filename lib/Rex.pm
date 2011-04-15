package Rex;

use strict;
use warnings;

use Rex::Logger;

require Exporter;
use base qw(Exporter);

use vars qw(@EXPORT $VERSION @CONNECTION_STACK);

@EXPORT = qw($VERSION);
$VERSION = "0.3.99.3";


sub push_connection {
   push @CONNECTION_STACK, $_[0];
}

sub pop_connection {
   pop @CONNECTION_STACK;
}

sub get_current_connection {
   $CONNECTION_STACK[-1];
}

sub is_ssh {
   return $CONNECTION_STACK[-1]->{"ssh"};
}

1;
