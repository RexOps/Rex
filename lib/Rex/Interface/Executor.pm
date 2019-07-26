#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Executor;

use strict;
use warnings;

# VERSION

use Data::Dumper;
use Module::Runtime qw(use_module);

sub create {
  my ( $class, $type ) = @_;

  unless ($type) {
    $type = "Default";
  }

  my $class_name = "Rex::Interface::Executor::$type";
  eval { use_module( $class_name ) }
      or die("Error loading file interface $type.\n$@");

  return $class_name->new;

}

1;
