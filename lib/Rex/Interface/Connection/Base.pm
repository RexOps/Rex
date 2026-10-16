#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::Connection::Base;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Fs;
use Rex::Interface::Exec;
use constant LAST_INDEX => -1;

my $hash_ref_type = 'HASH';

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{__sudo_options__} = [];
  $self->{__doas_options__} = [];

  return $self;
}

sub error                 { die("Must be implemented by Interface Class"); }
sub connect               { die("Must be implemented by Interface Class"); }
sub disconnect            { die("Must be implemented by Interface Class"); }
sub get_connection_object { die("Must be implemented by Interface Class"); }
sub is_connected          { die("Must be implemented by Interface Class"); }
sub is_authenticated      { die("Must be implemented by Interface Class"); }
sub get_connection_type   { die("Must be implemented by Interface Class") }
sub reconnect             { }

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

  if ( exists $self->{__auth_info__} ) {
    return $self->{__auth_info__}->{user};
  }

  return "";
}

sub get_auth {
  my ($self) = @_;

  if ( exists $self->{__auth_info__} ) {
    return $self->{__auth_info__};
  }
}

sub push_sudo_options {
  my ( $self, @option ) = @_;
  if ( ref $option[0] eq $hash_ref_type ) {
    push @{ $self->{__sudo_options__} }, $option[0];
  }
  else {
    push @{ $self->{__sudo_options__} }, {@option};
  }
  return $self->{__sudo_options__};
}

sub get_current_sudo_options {
  my ($self) = @_;
  return $self->{__sudo_options__}->[LAST_INDEX];
}

sub push_use_sudo {
  my ( $self, $use ) = @_;
  push @{ $self->{__use_sudo__} }, $use;
  return $self->{__use_sudo__};
}

sub get_current_use_sudo {
  my ($self) = @_;

  if ( $self->{is_sudo} ) {
    return 1;
  }
  return $self->{__use_sudo__}->[LAST_INDEX];
}

sub pop_sudo_options {
  my ($self) = @_;
  my $popped = pop @{ $self->{__sudo_options__} };
  return $popped;
}

sub pop_use_sudo {
  my ($self) = @_;
  my $popped = pop @{ $self->{__use_sudo__} };
  return $popped;
}

sub run_sudo_unmodified {
  my ( $self, $code ) = @_;
  $self->push_sudo_options( {} );
  $code->();
  my $popped = $self->pop_sudo_options();
  return $popped;
}

sub push_doas_options {
  my ( $self, @option ) = @_;

  my $value =
    ref $option[0] eq $hash_ref_type
    ? $option[0]
    : {@option};

  return push @{ $self->{__doas_options__} }, $value;
}

sub get_current_doas_options {
  my ($self) = @_;
  return $self->{__doas_options__}->[LAST_INDEX];
}

sub push_use_doas {
  my ( $self, $use ) = @_;

  return push @{ $self->{__use_doas__} }, $use;
}

sub get_current_use_doas {
  my ($self) = @_;

  if ( $self->{is_doas} ) {
    return 1;
  }
  return $self->{__use_doas__}->[LAST_INDEX];
}

sub pop_doas_options {
  my ($self) = @_;
  return pop @{ $self->{__doas_options__} };
}

sub pop_use_doas {
  my ($self) = @_;
  return pop @{ $self->{__use_doas__} };
}

sub run_doas_unmodified {
  my ( $self, $code ) = @_;
  $self->push_doas_options( {} );
  $code->();
  return $self->pop_doas_options();
}

1;
