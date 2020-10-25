#
# (c) Ferenc Erki <erkiferenc@gmail.com>, adjust GmbH
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell::Idrac;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Shell::Default;
use base qw(Rex::Interface::Shell::Default);

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $class );

  return $self;
}

sub detect {
  my ( $self, $con ) = @_;

  my ($output);
  eval {
    ($output) = $con->direct_exec('version');
    1;
  };
  if ( $output && $output =~ m/SM CLP Version: / ) {
    return 1;
  }

  return 0;
}

sub exec {
  my ( $self, $cmd, $option ) = @_;
  return $cmd;
}

1;
