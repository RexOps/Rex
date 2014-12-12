#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Shared::Var::Scalar;

use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);
use Data::Dumper;

use Storable;

sub __lock(&);
sub __retr;
sub __store;

sub TIESCALAR {
  my $self = { varname => $_[1], };
  bless $self, $_[0];
}

sub STORE {
  my $self  = shift;
  my $value = shift;

  return __lock {
    my $ref = __retr;
    my $ret = $ref->{ $self->{varname} } = $value;
    __store $ref;

    return $ret;
  };

}

sub FETCH {
  my $self = shift;

  return __lock {
    my $ref = __retr;
    return $ref->{ $self->{varname} };
  };

}

sub __lock(&) {

  sysopen( my $dblock, "vars.db.lock", O_RDONLY | O_CREAT ) or die($!);
  flock( $dblock, LOCK_SH ) or die($!);

  my $ret = &{ $_[0] }();

  close($dblock);

  return $ret;
}

sub __store {
  my $ref = shift;
  store( $ref, "vars.db" );
}

sub __retr {

  if ( !-f "vars.db" ) {
    return {};
  }

  return retrieve("vars.db");

}

1;
