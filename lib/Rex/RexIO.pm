#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::RexIO;

use strict;
use warnings;
use Carp;
require Rex::Commands;
use Data::Dumper;

Rex::Config->set_cache_type("RexIO");

Rex::Config->register_set_handler(
  "rexio",
  sub {
    my ($data) = @_;
    confess "No server given."   if !exists $data->{server};
    confess "No user given."     if !exists $data->{user};
    confess "No password given." if !exists $data->{password};

    Rex::Config->set( "rexio_server",   $data->{server} );
    Rex::Config->set( "rexio_user",     $data->{user} );
    Rex::Config->set( "rexio_password", $data->{password} );
  }
);

1;
