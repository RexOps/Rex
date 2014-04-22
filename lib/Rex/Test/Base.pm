#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test::Base;

use strict;
use warnings;

#use Rex -base;
require Test::More;
require Rex::Commands;
use Rex::Commands::Box;
use Data::Dumper;
use Carp;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(test);

Rex::Commands::set( box => "VBox" );

=item new(name => $test_name)

Constructor if used in OO mode.

 my $test = Rex::Test::Base->new(name => "test_name");

=cut

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  $self->{name} ||= $file;

  return $self;
}

sub name {
  my ( $self, $name ) = @_;
  $self->{name} = $name;
}

sub vm_auth {
  my ( $self, %auth ) = @_;
  $self->{auth} = \%auth;
}

sub base_vm {
  my ( $self, $vm ) = @_;
  $self->{vm} = $vm;
}

sub test(&) {
  my $code = shift;
  my $test = __PACKAGE__->new;
  $code->($test);
}

sub run_task {
  my ( $self, $task ) = @_;

  my $box;
  box {
    $box = shift;
    $box->name( $self->{name} );
    $box->url( $self->{vm} );

    $box->network(
      1 => {
        type => "nat",
      }
    );

    $box->forward_port( ssh => [ 2222, 22 ] );

    $box->auth( %{ $self->{auth} } );
    $box->setup($task);
  };

  $self->{box} = $box;

  # connect to the machine
  Rex::connect(
    server => $box->ip,
    %{ $self->{auth} },
  );
}

sub ok {
  my ($self, $test, $msg) = @_;
  Test::More::ok($test, $msg);
}

sub finish {
  Test::More::done_testing();
}

our $AUTOLOAD;
sub AUTOLOAD {
  my $self = shift or return undef;
  ( my $method = $AUTOLOAD ) =~ s{.*::}{};

  if($method eq "DESTROY") {
    return;
  }

  my $pkg = __PACKAGE__ . "::$method";
  eval "use $pkg";
  if($@) {
    confess "Error loading $pkg. No such test method.";
  }

  my $p = $pkg->new;
  $p->run_test(@_);
}

1;
