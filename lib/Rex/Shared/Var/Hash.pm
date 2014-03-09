#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
  
package Rex::Shared::Var::Hash;
  
use strict;
use warnings;

use Data::Dumper;

use Fcntl qw(:DEFAULT :flock);
use Data::Dumper;

use Storable;

sub __lock(&);
sub __retr;
sub __store;


sub TIEHASH {
  my $self = {
    varname => $_[1],
  };

  bless $self, $_[0];
}

sub STORE {
  my $self = shift;
  my $key = shift;
  my $value = shift;

  return __lock {
    my $ref = __retr;
    my $ret = $ref->{$self->{varname}}->{$key} = $value;
    __store $ref;

    return $ret;
  };
  
}

sub FETCH {
  my $self = shift;
  my $key = shift;

  return __lock {
    my $ref = __retr;
    return $ref->{$self->{varname}}->{$key};
  };

}

sub DELETE {
  my $self = shift;
  my $key = shift;

  __lock {
    my $ref = __retr;
    delete $ref->{$self->{varname}}->{$key};
    __store $ref;
  };

}

sub CLEAR {
  my $self = shift;

  __lock {
    my $ref = __retr;
    $ref->{$self->{varname}} = {};
    __store $ref;
  };

}

sub EXISTS {
  my $self = shift;
  my $key = shift;

  return __lock {
    my $ref = __retr;
    return exists $ref->{$self->{varname}}->{$key};
  };

}

sub FIRSTKEY {
  my $self = shift;

  return __lock {
    my $ref = __retr;
    $self->{__iter__} = $ref->{$self->{varname}};

    my $temp = keys %{ $self->{__iter__} };
    return scalar each %{ $self->{__iter__} };
  };

}

sub NEXTKEY {
  my $self = shift;
  my $prevkey = shift;

  return scalar each %{ $self->{__iter__} };
}

sub DESTROY {
  my $self = shift;
}


sub __lock(&) {

  sysopen(my $dblock, "vars.db.lock", O_RDONLY | O_CREAT) or die($!);
  flock($dblock, LOCK_SH) or die($!);

  my $ret = &{ $_[0] }();

  close($dblock);
  
  return $ret;
}

sub __store {
  my $ref = shift;
  store($ref, "vars.db");
}

sub __retr {

  if(! -f "vars.db") {
    return {};
  }

  return retrieve("vars.db");

}

1;
