#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Exporter;

use warnings;

use Data::Dumper;

our @EXPORT;

no strict 'refs';

sub import {
  my ( $mod_to_register, %option ) = @_;
  my ( $mod_to_register_in, $file, $line ) = caller;

  if ( exists $option{register_in} && $option{register_in} ) {
    $mod_to_register_in = $option{register_in};
  }

  my $no_import = "";
  if ( exists $option{"-no"} && $option{"-no"} ) {
    $no_import = "," . join( ",", @{ $option{"-no"} } ) . ",";
  }

  for my $reg_func ( @{ $_[0] . "::EXPORT" } ) {
    if ( $no_import =~ m/,$reg_func,/ ) {
      next;
    }

    *{ $mod_to_register_in . "::" . $reg_func } =
      *{ $mod_to_register . "::" . $reg_func };
  }
}

use strict;

1;
