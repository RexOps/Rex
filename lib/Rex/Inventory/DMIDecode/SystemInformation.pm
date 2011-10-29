#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Inventory::DMIDecode::SystemInformation;

use strict;
use warnings;

use Rex::Inventory::DMIDecode::Section;
use base qw(Rex::Inventory::DMIDecode::Section);

__PACKAGE__->section("System Information");

__PACKAGE__->has([ 'Manufacturer',
                   'Product Name',
                   'UUID',
                   'SKU Number',
                   'Family',
                   'Version',
                   'Serial Number', ]);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

1;

