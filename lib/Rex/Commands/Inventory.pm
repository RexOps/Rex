#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Inventory - Inventor your systems

=head1 DESCRIPTION

With this module you can get an inventory of your system.

=head1 SYNOPSIS

 use Data::Dumper;
 task "inventory", "remoteserver", sub {
    my $inventory = inventor();
    print Dumper($inventory);
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Inventory;

use strict;
use warnings;

use Rex::Inventory;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(inventor inventory);

=item inventory

This function returns an hashRef of all gathered hardware. Use the Data::Dumper module to see its structure.

 task "get-inventory", sub {
    my $inventory = inventor();
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
