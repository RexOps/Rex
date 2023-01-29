#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::Shell::Sh;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Shell::Bash;

use base qw(Rex::Interface::Shell::Bash);

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $class );

  return $self;
}

1;
