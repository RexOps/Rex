#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::System;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::Hash;

sub info {

  return (
    eval {
      my %merge1        = ();
      my %merge2        = Rex::Hardware->get(qw/ All /);
      my %template_vars = ( %merge1, %merge2 );

      for my $info_key (qw(Network Host Kernel Memory Swap)) {

        my $flatten_info = {};

        if ( $info_key eq "Memory" ) {
          hash_flatten( $merge2{$info_key}, $flatten_info, "_", "memory" );
        }
        elsif ( $info_key eq "Swap" ) {
          hash_flatten( $merge2{$info_key}, $flatten_info, "_", "swap" );
        }
        elsif ( $info_key eq "Network" ) {
          hash_flatten( $merge2{$info_key}->{"networkconfiguration"},
            $flatten_info, "_" );
        }
        else {
          hash_flatten( $merge2{$info_key}, $flatten_info, "_" );
        }

        for my $key ( keys %{$flatten_info} ) {
          $template_vars{$key} = $flatten_info->{$key};
        }

      }

      return %template_vars;
    }
  );
}

1;
