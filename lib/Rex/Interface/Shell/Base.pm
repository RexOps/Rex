#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell::Base;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub new {
  my $class = shift;
  my $self  = {};
  $self->{path}            = undef;
  $self->{__inner_shell__} = undef;

  bless( $self, $class );

  return $self;
}

sub name {
  my ($self)     = @_;
  my $class_name = ref $self;
  my @parts      = split( /::/, $class_name );
  return lc( $parts[-1] );
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

sub detect {
  my ( $self, $con ) = @_;

  my $shell_class = ref $self || $self; # $self might be only the classname
  my @parts       = split /::/, $shell_class;
  my $last_part   = lc( $parts[-1] || "" );

  my ($shell_path) = $con->_exec("echo \$SHELL");
  if ( !$shell_path ) {

    # try it a second time
    # we need this sometimes because the tty allocation is too slow, or
    # doesn't work, or ???
    # it seems that this happens only for the very first command with
    # Net::OpenSSH when using a tty.
    Rex::Logger::debug(
      "Failed detecting shell in the first try. Trying again.");

    ($shell_path) = $con->_exec("echo \$SHELL");
  }

  $shell_path =~ s/(\r?\n)//gms; # remove unnecessary newlines

  if ( $shell_path && $shell_path =~ m/\/\Q$last_part\E$/ ) {
    return 1;
  }

  return 0;
}

1;
