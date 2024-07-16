#
# (c) Ferenc Erki <erkiferenc@gmail.com>, adjust GmbH
#

package Rex::Test::Base::has_dir;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;
use base qw(Rex::Test::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $path ) = @_;
  $self->ok( is_dir($path), "Found $path directory." );
}

1;
