#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell::Bash;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Interface::Shell::Base;
use base qw(Rex::Interface::Shell::Base);
use Data::Dumper;
use Net::OpenSSH::ShellQuoter;

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

# sub set_env {
#   my ( $self, $env ) = @_;
#   my $cmd = undef;
#
#   die("Error: env must be a hash")
#     if ( ref $env ne "HASH" );
#
#   while ( my ( $k, $v ) = each($env) ) {
#     $cmd .= "export $k=$v; ";
#   }
#   $self->{env} = $cmd;
# }

sub exec {
  my ( $self, $cmd, $option ) = @_;

  if ( exists $option->{path} ) {
    $self->path( $option->{path} );
  }

  Rex::Logger::debug("Shell/Bash: Got options:");
  Rex::Logger::debug( Dumper($option) );

  my $complete_cmd = $cmd;

  # if we need to execute without an sh command,
  # use the format_cmd key
  # if ( exists $option->{no_sh} ) {
  #   $complete_cmd = $option->{format_cmd};
  # }

  if ( exists $option->{cwd} ) {
    $complete_cmd = "cd $option->{cwd} && $complete_cmd";
  }

  if ( $self->{path} && !exists $self->{__env__}->{PATH} ) {
    $complete_cmd = "PATH=$self->{path}; export PATH; $complete_cmd ";
  }

  if ( $self->{locale} && !exists $option->{no_locales} ) {
    $complete_cmd = "LC_ALL=$self->{locale} ; export LC_ALL; $complete_cmd ";
  }

  if ( $self->{source_profile} ) {
    $complete_cmd =
      "[ -r ~/.profile ] && . ~/.profile >/dev/null 2>&1 ; $complete_cmd";
  }

  if ( $self->{source_global_profile} ) {
    $complete_cmd = ". /etc/profile >/dev/null 2>&1 ; $complete_cmd";
  }

  if ( exists $self->{__env__} ) {
    if ( ref $self->{__env__} eq "HASH" ) {
      for my $key ( keys %{ $self->{__env__} } ) {
        my $val = $self->{__env__}->{$key};
        $val =~ s/"/\\"/gms;
        if ( exists $self->{__sudo_env__} && $self->{__sudo_env__} ) {
          $complete_cmd = " $key=\"$val\" $complete_cmd ";
        }
        else {
          $complete_cmd = " export $key=\"$val\" ; $complete_cmd ";
        }
      }
    }
    else {
      $complete_cmd = $self->{__env__} . " $complete_cmd ";
    }
  }

# this is due to a strange behaviour with Net::SSH2 / libssh2
# it may occur when you run rex inside a kvm virtualized host connecting to another virtualized vm on the same hardware
  if ( Rex::Config->get_sleep_hack ) {
    $complete_cmd .= " ; f=\$? ; sleep .00000001 ; exit \$f";
  }

  if ( exists $option->{preprocess_command}
    && ref $option->{preprocess_command} eq "CODE" )
  {
    $complete_cmd = $option->{preprocess_command}->($complete_cmd);
  }

  # rewrite the command again
  if ( exists $option->{format_cmd} ) {
    $complete_cmd =~ s/\{\{CMD\}\}/$cmd/;
  }

  if ( $self->{__inner_shell__} ) {
    my $quoter = Net::OpenSSH::ShellQuoter->quoter("sh");
    $complete_cmd = "sh -c " . $quoter->quote($complete_cmd);
  }

  if ( exists $option->{prepend_command} && $option->{prepend_command} ) {
    $complete_cmd = $option->{prepend_command} . " $complete_cmd";
  }

  return $complete_cmd;
}

1;
