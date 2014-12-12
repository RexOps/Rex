#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Inventory - Get an inventory of your systems

=head1 DESCRIPTION

With this module you can get an inventory of your system.

All these functions will not be reported. These functions don't modify anything.

=head1 SYNOPSIS

 use Data::Dumper;
 task "inventory", "remoteserver", sub {
   my $inventory = inventory();
   print Dumper($inventory);
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Inventory;

use strict;
use warnings;

# VERSION

use Rex::Inventory;

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(inventor inventory);

=item inventory

This function returns a hashRef of all gathered hardware. Use the Data::Dumper module to see its structure.

 task "get_inventory", sub {
   my $inventory = inventory();
   print Dumper($inventory);
 };

=cut

sub inventory {
  my $inv = Rex::Inventory->new;

  return $inv->get;
}

sub inventor {
  return inventory();
}

=back

=cut

1;
