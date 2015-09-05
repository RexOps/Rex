#
# (c) Ferenc Erki <erkiferenc@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell::Cisco;

use strict;
use warnings;

# VERSION

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

  my ($output) = $con->_exec('sh version');
  if ( defined $output && $output =~ m/Cisco IOS/ ) {
    return 1;
  }

  return 0;
}

sub exec {
  my ( $self, $cmd, $option ) = @_;
  return $cmd;
}

1;
