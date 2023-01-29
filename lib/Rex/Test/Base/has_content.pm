#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test::Base::has_content;

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
  my ( $self, $file, $test ) = @_;

  return $self->ok( 0, "has_content: $file not found" ) unless is_file($file);

  my $content = cat $file;
  $self->ok( ( $content =~ $test ) >= 1, "Content of $file contain $test." );
}

1;
