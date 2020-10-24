#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Notify;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{__types__}             = {};
  $self->{__postponed__}         = [];
  $self->{__running_postponed__} = 0;
  $self->{__in_notify__}         = 0;

  return $self;
}

sub add {
  my ( $self, %option ) = @_;

  return if ( $self->{__in_notify__} );

  if ( exists $self->{__types__}->{ $option{type} }->{ $option{name} } ) {
    Rex::Logger::debug(
      "A resource of the type $option{type} and name $option{name}"
        . "already exists.",
      "warn"
    );
    return;
  }

  $self->{__types__}->{ $option{type} }->{ $option{name} } = {
    postpone => $option{postpone} || 0,
    options  => $option{options},
    cb       => $option{cb},
  };
}

sub run {
  my ( $self, %option ) = @_;

  Rex::Logger::debug("Try to notify $option{type} -> $option{name}");

  if ( exists $self->{__types__}->{ $option{type} }
    && exists $self->{__types__}->{ $option{type} }->{ $option{name} }
    && exists $self->{__types__}->{ $option{type} }->{ $option{name} }->{cb}
    && $self->{__types__}->{ $option{type} }->{ $option{name} }->{postpone} ==
    0 )
  {
    Rex::Logger::debug("Running notify $option{type} -> $option{name}");

    my $cb = $self->{__types__}->{ $option{type} }->{ $option{name} }->{cb};

    $self->{__in_notify__} = 1;

    $cb->(
      $self->{__types__}->{ $option{type} }->{ $option{name} }->{options} );

    $self->{__in_notify__} = 0;
  }
  else {
    if ( !$self->{__running_postponed__} ) {
      Rex::Logger::debug(
        "Can't notify $option{type} -> $option{name}. Postponing...");
      $self->_postpone(%option);
    }
    else {
      Rex::Logger::info(
        "Can't run postponed notification. "
          . "Resource not found ($option{type} -> $option{name})",
        "warn"
      );
    }
  }

}

sub run_postponed {
  my ($self) = @_;
  $self->{__running_postponed__} = 1;
  Rex::Logger::debug("Running postponed notifications.");
  for my $p ( @{ $self->{__postponed__} } ) {
    $self->run( %{$p} );
  }
}

sub _postpone {
  my ( $self, %option ) = @_;
  push @{ $self->{__postponed__} }, \%option;
}

1;
