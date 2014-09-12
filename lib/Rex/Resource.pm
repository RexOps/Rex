#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Resource;

use strict;
use warnings;

use Rex::Constants;

our $INSIDE_RES = 0;
our @CURRENT_RES;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub name { (shift)->{name}; }
sub type { (shift)->{type}; }

sub call {
  my ( $self, $name, %params ) = @_;
  $INSIDE_RES = 1;
  push @CURRENT_RES, $self;

  $self->{res_name} = $name;
  $self->{res_ensure} = $params{ensure} ||= present;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => $self->type, name => $name );

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
    Rex::Logger::info( "Resource execution failed: $name", "error" );
    $failed = 1;
  };

  if ( $self->changed ) {
    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      failed  => $failed,
      message => $self->name . " changed.",
    );
  }
  else {
    Rex::get_current_connection()->{reporter}->report(
      changed => 0,
      failed  => $failed,
      message => $self->name . " not changed.",
    );
  }

  if ( exists $params{on_change} && $self->changed ) {
    $params{on_change}->();
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => $self->type, name => $name );

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

sub changed {
  my ( $self, $changed ) = @_;

  if ( defined $changed ) {
    $self->{changed} = $changed;
  }
  else {
    return $self->{changed};
  }
}

1;
