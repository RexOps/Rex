#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::MultiSub;

use strict;
use warnings;

# VERSION

use Moose;
use MooseX::Params::Validate;
use Rex::MultiSub::LookupTable;

use Data::Dumper;
use Carp;

has methods => (
  is      => 'rw',
  isa     => 'Rex::MultiSub::LookupTable',
  default => sub {
    Rex::MultiSub::LookupTable->instance;
  }
);

has name        => ( is => 'ro', isa => 'Str' );
has function    => ( is => 'ro', isa => 'CodeRef' );
has params_list => ( is => 'ro', isa => 'ArrayRef' );

sub validate { }
sub error    { }

sub BUILD {
  my ($self) = @_;
  $self->methods->add( $self->name, $self->params_list, $self->function );
}

sub export {
  my ( $self, $ns, $global ) = @_;

  my $name = $self->name;

  no strict 'refs';
  no warnings 'redefine';

  *{"${ns}::$name"} = sub {
    $self->dispatch(@_);
  };

  if ($global) {

    # register in caller namespace
    push @{ $ns . "::ISA" }, "Rex::Exporter"
      unless ( grep { $_ eq "Rex::Exporter" } @{ $ns . "::ISA" } );
    push @{ $ns . "::EXPORT" }, $self->name;
  }

  use strict;
  use warnings;
}

sub dispatch {
  my ( $self, @args ) = @_;

  my @errors;
  my $exec;
  my @all_args;
  my $found = 0;

  for my $f (
    sort {
      scalar( @{ $b->{params_list} } ) <=>
        scalar( @{ $a->{params_list} } )
    } @{ $self->methods->data->{ $self->name } }
    )
  {

    eval {
      @all_args = $self->validate( $f, @args );
      $found = 1;
      1;
    } or do {
      push @errors, $@;

      # print "Err: $@\n";
      # TODO catch no "X parameter was given" errors
      next;
    };

    $exec = $f->{code};

    last;
  }
  if ( !$found ) {
    my @err_msg;
    for my $err (@errors) {
      my ($fline) = split( /\n/, $err );
      push @err_msg, $fline;
    }

    $self->error(@err_msg);
  }

  $self->call( $exec, @all_args );
}

sub call {
  my ( $self, $code, @args ) = @_;
  $code->(@args);
}

1;
