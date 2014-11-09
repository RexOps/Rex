#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::Interface::Shell::Base;

use warnings;

sub new {
  my $class = shift;
  my $self  = {};
  $self->{path}            = undef;
  $self->{__inner_shell__} = undef;

  bless( $self, $class );

  return $self;
}

sub set_environment {
  my ( $self, $env ) = @_;
  $self->{__env__} = $env;
}

sub set_inner_shell {
  my ( $self, $use_inner_shell ) = @_;
  $self->{__inner_shell__} = $use_inner_shell;
}

sub set_locale {
  my ( $self, $locale ) = @_;
  $self->{locale} = $locale;
}

sub set_sudo_env {
  my ( $self, $sudo_env ) = @_;
  $self->{__sudo_env__} = $sudo_env;
}

1;
