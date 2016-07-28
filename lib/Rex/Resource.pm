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
use Hash::Merge qw/merge/;

require Rex::Resource::Common;

our @CURRENT_RES;

sub is_inside_resource { ref $CURRENT_RES[-1] ? 1 : 0 }
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

  if ( ref $_[1] eq "HASH" ) {
    my ( $self, $name ) = @_;

    # multiple resource call
    for my $n ( keys %{$name} ) {
      my $this_p = $name->{$n};
      if ( $_[2] && ref $_[2] eq "HASH" ) {

        # some defaults to merge
        $this_p = merge( $this_p, $_[2] );
      }

      $self->call( $n, %{$this_p} );
    }

    return;
  }

  my ( $self, $name, %params ) = @_;

  if ( ref $name eq "ARRAY" ) {

    # multiple resource call
    for my $n ( @{$name} ) {
      $self->call( $n, %params );
    }

    return;
  }

  push @CURRENT_RES, $self;

  #### check and run before hook
  eval {
    my @new_args =
      Rex::Hook::run_hook( $self->type => "before", $name, %params );
    if (@new_args) {
      ( $name, %params ) = @new_args;
    }
    1;
  } or do {
    die( "Before hook failed. Cancelling " . $self->type . " resource: $@" );
  };
  ##############################

  $self->set_all_parameters(%params);

  $self->{res_name} = $name;
  $self->{res_ensure} = $params{ensure} ||= present;

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => $self->display_name, name => $name );

  my $failed     = 0;
  my $failed_msg = "";

  eval {
    my ( $provider, $mod_config ) = $self->{cb}->( \%params );

    if ( $provider =~ m/^[a-zA-Z0-9_:]+$/ && ref $mod_config eq "HASH" ) {

      # new resource interface
      # old one is already executed via $self->{cb}->(\%params)

      my $provider_o = $provider->new(
        type   => $self->type,
        config => $mod_config,
        name   => ( $mod_config->{name} || $name )
      );

      # TODO add dry-run feature
      $provider_o->process;

      #### check and run after hook
      Rex::Hook::run_hook( $self->type => "after", $name, %{$mod_config} );
      ##############################

      Rex::Resource::Common::emit( $provider_o->status(),
            $provider_o->type . "["
          . $provider_o->name
          . "] is now "
          . $self->{res_ensure} . "."
          . $provider_o->message );
    }
    else {
      # TODO add deprecation warning
    }

    1;
  } or do {
    $failed_msg = $@;
    Rex::Logger::info( $failed_msg, "error" );
    Rex::Logger::info(
      "Resource execution failed: " . $self->display_name . "[$name]",
      "error" );
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

  # TODO: resource autodie?
  die $failed_msg if $failed;
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
