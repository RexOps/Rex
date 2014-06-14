#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Shared::Var;

use strict qw(vars subs);
use warnings::register;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Data::Dumper;

@EXPORT = qw(share);

sub share {
  my @vars = @_;
  my ( $package, $file, $line ) = caller;

  my ( $sigil, $sym );
  for my $var (@vars) {

    if ( ( $sigil, $sym ) = ( $var =~ /^([\$\@\%\*\&])(.+)/ ) ) {
      $sym = "${package}::$sym";

      if ( $sigil eq "\$" ) {
        eval "use Rex::Shared::Var::Scalar;";
        tie $$sym, "Rex::Shared::Var::Scalar", $sym;
        *$sym = \$$sym;
      }
      elsif ( $sigil eq "\@" ) {
        eval "use Rex::Shared::Var::Array;";
        tie @$sym, "Rex::Shared::Var::Array", $sym;
        *$sym = \@$sym;
      }
      elsif ( $sigil eq "\%" ) {
        eval "use Rex::Shared::Var::Hash;";
        tie %$sym, "Rex::Shared::Var::Hash", $sym;
        *$sym = \%$sym;
      }
    }

  }
}

1;
