#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource;

use strict;
use warnings;

# VERSION

use Rex::Constants;

our $INSIDE_RES = 0;
our @CURRENT_RES;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{__status__} = "unchanged";

  return $self;
}

sub name         { (shift)->{name}; }
sub display_name { (shift)->{display_name}; }
sub type         { (shift)->{type}; }

sub call {
  my ( $self, $name, %params ) = @_;

  if ( ref $name eq "HASH" ) {

    # multiple resource call
    for my $n ( keys %{$name} ) {
      $self->call( $n, %{ $name->{$n} } );
    }

    return;
  }

  $INSIDE_RES = 1;
  push @CURRENT_RES, $self;

  $self->{res_name} = $name;
  $self->{res_ensure} = $params{ensure} ||= present;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => $self->display_name, name => $name );

  # make parameters automatically availabel in templates
  # store old values so that we can recover them after resource finish
  my %old_values;
  for my $key ( keys %params ) {
    $old_values{$key} = Rex::Config->get($key);
    Rex::Config->set( $key => $params{$key} );
  }

  my $failed = 0;
  eval {
    $self->{cb}->( \%params );
    1;
  } or do {
    Rex::Logger::info( $@,                                 "error" );
    Rex::Logger::info( "Resource execution failed: $name", "error" );
    $failed = 1;
  };

  if ( $self->was_updated ) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      failed  => $failed,
      message => $self->message,
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report(
      changed => 0,
      failed  => $failed,
      message => $self->display_name . " not changed.",
    );
  }

  if ( exists $params{on_change} && $self->was_updated ) {
    $params{on_change}->( $self->{__status__} );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => $self->display_name, name => $name );

  $INSIDE_RES = 0;
  pop @CURRENT_RES;

  # recover old values
  for my $key ( keys %old_values ) {
    if ( defined $old_values{$key} ) {
      Rex::Config->set( $key => $old_values{$key} );
    }
    else {
      Rex::Config->set( $key => undef );
    }
  }
}

sub was_updated {
  my ($self) = @_;

  if ( $self->changed || $self->created || $self->removed ) {
    return 1;
  }

  return 0;
}

sub changed {
  my ( $self, $changed ) = @_;

  if ( defined $changed ) {
    $self->{__status__} = "changed";
  }
  else {
    return ( $self->{__status__} eq "changed" ? 1 : 0 );
  }
}

sub created {
  my ( $self, $created ) = @_;

  if ( defined $created ) {
    $self->{__status__} = "created";
  }
  else {
    return ( $self->{__status__} eq "created" ? 1 : 0 );
  }
}

sub removed {
  my ( $self, $removed ) = @_;

  if ( defined $removed ) {
    $self->{__status__} = "removed";
  }
  else {
    return ( $self->{__status__} eq "removed" ? 1 : 0 );
  }
}

sub message {
  my ( $self, $message ) = @_;

  if ( defined $message ) {
    $self->{message} = $message;
  }
  else {
    return ( $self->{message} || ( $self->display_name . " changed." ) );
  }
}

1;
