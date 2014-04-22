#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test::Base::has_content;

use strict;
use warnings;

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
  my $content = cat $file;
  $self->test_ok(($content =~ $test) >= 1, "Content of $file contain $test.");
}

1;
