#
# (c) Ferenc Erki <erkiferenc@gmail.com>
#

package Rex::Pkg::Test;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless $self, $proto;

  $self->{commands} = { install => 'echo %s' };

  return $self;
}

1;
