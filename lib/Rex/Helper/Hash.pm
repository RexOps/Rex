#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::Hash;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(hash_flatten);

sub hash_flatten {
  my ( $in, $out, $sep, @super_keys ) = @_;

  if ( ref($in) eq "HASH" ) {
    for my $key ( keys %{$in} ) {
      push @super_keys, $key;
      if ( ref( $in->{$key} ) ) {
        hash_flatten( $in->{$key}, $out, $sep, @super_keys );
      }
      else {
        my $new_key_name = join( $sep, @super_keys );
        $new_key_name =~ s/[^A-Za-z0-9_]/_/g;
        $out->{$new_key_name} = $in->{$key};
      }
      pop @super_keys;
    }
  }
  elsif ( ref($in) eq "ARRAY" ) {
    my $counter = 0;
    for my $val ( @{$in} ) {
      if ( ref($val) ) {
        push @super_keys, $counter;
        hash_flatten( $val, $out, $sep, @super_keys );
        pop @super_keys;
      }
      else {
        my $new_key_name = join( $sep, @super_keys ) . "_$counter";
        $new_key_name =~ s/[^A-Za-z0-9_]/_/g;
        $out->{$new_key_name} = $val;
      }
      $counter++;
    }
  }
}

1;
