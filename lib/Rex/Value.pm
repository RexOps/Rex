#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
#
# this is a simple helper class for the get() function

package Rex::Value;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub value {
  my ($self) = @_;
  return $self->{value};
}

1;
