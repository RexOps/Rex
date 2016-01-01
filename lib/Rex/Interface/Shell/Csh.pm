#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell::Csh;

use strict;
use warnings;

# VERSION

use Rex::Interface::Shell::Base;
use base qw(Rex::Interface::Shell::Base);

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $class );

  return $self;
}

sub path {
  my ( $self, $path ) = @_;
  $self->{path} = $path;
}

sub source_global_profile {
  my ( $self, $parse ) = @_;
  $self->{source_global_profile} = $parse;
}

sub source_profile {
  my ( $self, $parse ) = @_;
  $self->{source_profile} = $parse;
}

sub set_locale {
  my ( $self, $locale ) = @_;
  $self->{locale} = $locale;
}

# sub set_env {
#   my ( $self, $env ) = @_;
#   my $cmd = undef;
#
#   die("Error: env must be a hash")
#     if ( ref $env ne "HASH" );
#
#   while ( my ( $k, $v ) = each($env) ) {
#     $cmd .= "setenv $k \"$v\"; ";
#     $self->{env_raw} .= "$k $v";
#   }
#
#   $self->{env} = $cmd;
# }

sub exec {
  my ( $self, $cmd, $option ) = @_;

  if ( exists $option->{path} ) {
    $self->path( $option->{path} );
  }

  # if ( exists $option->{env} ) {
  #   $self->set_env( $option->{env} );
  # }

  my $complete_cmd = $cmd;

  # if we need to execute without an sh command,
  # use the format_cmd key
  if ( exists $option->{no_sh} ) {
    $complete_cmd = $option->{format_cmd};
  }

  if ( exists $option->{cwd} ) {
    $complete_cmd = "cd $option->{cwd} && $complete_cmd";
  }

  if ( $self->{path} && !exists $self->{__env__}->{PATH} ) {
    $complete_cmd = "set PATH=$self->{path}; $complete_cmd ";
  }

  if ( $self->{locale} ) {
    $complete_cmd = "set LC_ALL=$self->{locale} ; $complete_cmd ";
  }

  if ( $self->{source_profile} ) {

    # csh is using .login
    $complete_cmd = "source ~/.login >& /dev/null ; $complete_cmd";
  }

  if ( $self->{source_global_profile} ) {
    $complete_cmd = "source /etc/profile >& /dev/null ; $complete_cmd";
  }

  if ( exists $self->{__env__} ) {
    if ( ref $self->{__env__} eq "HASH" ) {
      for my $key ( keys %{ $self->{__env__} } ) {
        my $val = $self->{__env__}->{$key};
        $val =~ s/"/"'"'"/gms;
        $complete_cmd = " setenv $key \"$val\" ; $complete_cmd ";
      }
    }
    else {
      $complete_cmd = $self->{__env__} . " $complete_cmd ";
    }
  }

# this is due to a strange behaviour with Net::SSH2 / libssh2
# it may occur when you run rex inside a kvm virtualized host connecting to another virtualized vm on the same hardware
  if ( Rex::Config->get_sleep_hack ) {
    $complete_cmd .= " ; set f=\$? ; sleep .00000001 ; exit \$f";
  }

  # rewrite the command again
  if ( exists $option->{format_cmd} ) {
    $complete_cmd =~ s/\{\{CMD\}\}/$cmd/;
  }

  return $complete_cmd;
}

1;
