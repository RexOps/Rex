#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::UserAgent;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use base 'LWP::UserAgent';

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub get_basic_credentials {
  my ($self) = @_;

  if ( exists $self->{__user__} && $self->{__password__} ) {
    return $self->{__user__}, $self->{__password__};
  }
  return;
}

sub get {
  my ( $self, $url, %option ) = @_;
  if ( exists $option{user} ) {
    $self->{__user__} = $option{user};
  }
  if ( exists $option{password} ) {
    $self->{__password__} = $option{password};
  }

  return $self->SUPER::get($url);
}

1;
