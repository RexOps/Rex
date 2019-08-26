#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Function::Common;

use strict;
use warnings;

# VERSION

require Exporter;
require Rex::Config;
use Data::Dumper;
use base qw(Exporter);
use vars qw(@EXPORT);
use MooseX::Params::Validate;
use Rex::MultiSub::Function;

@EXPORT = qw(function);

sub function {
  my ( $name, $options, $function ) = @_;
  my $name_save = $name;
  if ( $name_save !~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ ) {
    Rex::Logger::info(
      "Please use only the following characters for function names:", "warn" );
    Rex::Logger::info( "  A-Z, a-z, 0-9 and _", "warn" );
    Rex::Logger::info( "Also the function should start with A-Z or a-z",
      "warn" );
    die "Wrong function name syntax.";
  }

  my $sub = Rex::MultiSub::Function->new(
    name           => $name_save,
    function       => $function,
    params_list    => $options->{params_list},
    test_wantarray => 1,
  );

  my ( $class, $file, @tmp ) = caller;

  $sub->export( $class, $options->{export} );
}

1;
