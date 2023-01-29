#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test::Base::has_output;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -minimal;
use Rex::Helper::Run;
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
  my ( $self, $exec, $wanted_output ) = @_;
  my $output = i_exec $exec;
  $self->ok( $output eq $wanted_output, "Output of $exec is as expected." );
}

1;
