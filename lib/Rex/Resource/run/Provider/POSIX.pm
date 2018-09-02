#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::run::Provider::POSIX - POSIX compatible run provider

=head1 DESCRIPTION

=head1 PARAMETER

=cut

package Rex::Resource::run::Provider::POSIX;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Data::Dumper;

extends qw(Rex::Resource::Provider);
with qw(Rex::Resource::Role::Testable);

sub test {
  my ($self) = @_;

  # we have to do something
  return 0;
}

sub present {
  my ($self) = @_;

  my $exec = Rex::Interface::Exec->create;
  my $fs   = Rex::Interface::Fs->create;

  my $path;

  if ( !Rex::Config->get_no_path_cleanup() ) {
    $path = join( ":", Rex::Config->get_path() );
  }

  if(exists $self->config->{path}) {
    if (ref $self->config->{path} eq "ARRAY") {
      $path = join( ":", $self->config->{path});
    }
    else {
      $path = $self->config->{path};
    }
  }

  # my $quoter = Net::OpenSSH::ShellQuoter->quoter( $exec->shell->name );

  # print Dumper $self;

  my $cmd = $self->config->{command};
  my $options = {};

  if($self->config->{env}) {
    $options->{env} = $self->config->{env};
  }

  if($self->config->{cwd}) {
    $options->{cwd} = $self->config->{cwd};
  }

  my ( $out, $err ) = $exec->exec( $cmd, $path, $options );

  chomp $out if $out;
  chomp $err if $err;

  if ( !defined $out ) {
    $out = "";
  }

  if ( !defined $err ) {
    $err = "";
  }

  my $ret = {};
  $ret->{value}     = $out;
  $ret->{exit_code} = $?;
  $ret->{changed}   = 1;

  return $ret;
}

1;

