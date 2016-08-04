#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::DSL::Common;

use strict;
use warnings;

# VERSION

require Exporter;
require Rex::Config;
use Data::Dumper;
use base qw(Exporter);
use vars qw(@EXPORT);
use MooseX::Params::Validate;

@EXPORT = qw(dsl);

sub dsl {
  my ( $name, $options, $function ) = @_;
}

1;
