#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
  
package Rex::Interface::Connection::Base;
  
use strict;
use warnings;

use Rex::Interface::Fs;
use Rex::Interface::Exec;

sub new {
  my $that = shift;
  my $proto = ref($that) || $that;
  my $self = { @_ };

  bless($self, $proto);

  return $self;
}

sub error { die("Must be implemented by Interface Class"); };
sub connect { die("Must be implemented by Interface Class"); };
sub disconnect { die("Must be implemented by Interface Class"); };
sub get_connection_object { die("Must be implemented by Interface Class"); };
sub is_connected { die("Must be implemented by Interface Class"); };
sub is_authenticated { die("Must be implemented by Interface Class"); };
sub get_connection_type { die("Must be implemented by Interface Class") };
sub reconnect {};

sub get_fs_connection_object {
  my ($self) = @_;
  return $self;
}

sub get_fs {
  my $fs = Rex::Interface::Fs->create;
  return $fs;
}

sub get_exec {
  my $exec = Rex::Interface::Exec->create;
  return $exec;
}

sub server {
  my ($self) = @_;
  return $self->{server};
}

sub get_auth_user {
  my ($self) = @_;

  if(exists $self->{__auth_info__}) {
    return $self->{__auth_info__}->{user};
  }

  return "";
}

sub get_auth {
  my ($self) = @_;

  if(exists $self->{__auth_info__}) {
    return $self->{__auth_info__};
  }
}

1;
