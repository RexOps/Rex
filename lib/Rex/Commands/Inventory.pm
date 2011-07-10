#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Inventory;

use strict;
use warnings;

use Rex::Inventory;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(inventor);

sub inventor {
   my $inv = Rex::Inventory->new;

   return $inv->get;
}

1;
