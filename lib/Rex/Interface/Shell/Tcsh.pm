#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell::Tcsh;

use 5.010001;
use strict;
use warnings;
use Rex::Interface::Shell::Csh;

our $VERSION = '9999.99.99_99'; # VERSION

use base qw(Rex::Interface::Shell::Csh);

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $class );

  return $self;
}

1;
