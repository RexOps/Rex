#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Helper::Array;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(array_uniq);

sub array_uniq {
   my (@array) = @_;

   my %all = ();
   @all{@array} = 1;
   return keys %all;
}

1;
