#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Helper::Hash;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(hash_flatten);

sub hash_flatten {
   my ($in, $out, $sep, @super_keys) = @_;

   if(ref($in) eq "HASH") {
      for my $key (keys %{$in}) {
         push @super_keys, $key;
         if(ref($in->{$key})) {
            hash_flatten($in->{$key}, $out, $sep, @super_keys);
         }
         else {
            $out->{join($sep, @super_keys)} = $in->{$key};
         }
         pop @super_keys;
      }
   }
   elsif(ref($in) eq "ARRAY") {
      my $counter = 0;
      for my $val (@{$in}) {
         if(ref($val)) {
            push @super_keys, $counter;
            hash_flatten($val, $out, $sep, @super_keys);
            pop @super_keys;
         }
         else {
            $out->{join($sep, @super_keys) . "_$counter"} = $val;
         }
         $counter++;
      }
   }
}

1;
