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

our @CURRENT_RES;

sub is_inside_resource   { ref $CURRENT_RES[-1] ? 1 : 0 }
sub get_current_resource { $CURRENT_RES[-1] }

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

  push @CURRENT_RES, $self;

  $self->set_all_parameters(%params);

  $self->{res_name}   = $name;
  $self->{res_ensure} = $params{ensure} ||= present;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => $self->display_name, name => $name );

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

  pop @CURRENT_RES;
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

sub set_parameter {
  my ( $self, $key, $value ) = @_;
  $self->{__res_parameters__}->{$key} = $value;
}

sub set_all_parameters {
  my ( $self, %params ) = @_;
  $self->{__res_parameters__} = \%params;
}

sub get_all_parameters {
  my ($self) = @_;
  return $self->{__res_parameters__};
}

1;
