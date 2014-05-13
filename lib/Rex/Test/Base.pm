#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Test::Base - Basic Test Module

=head1 DESCRIPTION

This module is a basic Test module to test your Code with the help of local VMs. To create a test you first have to create the "t" directory.
Then you can create your test files inside this directory.

=head1 EXAMPLE

 use Rex::Test::Base;
 use Data::Dumper;
 use Rex -base;

 test {
   my $t = shift;

   $t->name("ubuntu test");

   $t->base_vm("http://box.rexify.org/box/ubuntu-server-12.10-amd64.ova");
   $t->vm_auth(user => "root", password => "box");

   $t->run_task("setup");

   $t->has_package("vim");
   $t->has_package("ntp");
   $t->has_package("unzip");

   $t->has_file("/etc/ntp.conf");

   $t->has_service_running("ntp");

   $t->has_content("/etc/passwd", qr{root:x:0:}ms);

   run "ls -l";
   $t->ok($? == 0, "ls -l returns success.");

   $t->finish;
 };

 1; # last line

=head1 METHODS

=over 4

=cut

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
  $self->{redirect_port} = 2222;

  return $self;
}

=item name($name)

The name of the test. For each test a new vm will be created named after $name.

=cut
sub name {
  my ( $self, $name ) = @_;
  $self->{name} = $name;
}

=item vm_auth(%auth)

Authentication option for the VM.

=cut
sub vm_auth {
  my ( $self, %auth ) = @_;
  $self->{auth} = \%auth;
}

=item base_vm($vm)

The url to a vm that should be used as base VM.

=cut
sub base_vm {
  my ( $self, $vm ) = @_;
  $self->{vm} = $vm;
}

sub test(&) {
  my $code = shift;
  my $test = __PACKAGE__->new;
  $code->($test);
}

=item redirect_port($port)

The redirected SSH port. Default 2222.

=cut
sub redirect_port {
  my ( $self, $port ) = @_;
  $self->{redirect_port} = $port;
}

=item run_task($task)

The task to run on the test vm.

=cut
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

    $box->forward_port( ssh => [ $self->{redirect_port}, 22 ] );

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
  my ( $self, $test, $msg ) = @_;
  Test::More::ok( $test, $msg );
}

sub finish {
  Test::More::done_testing();
}


=back

=head1 TEST METHODS

=over 4

=item has_content($file, $regexp)

Test if the content of $file matches against $regexp.

=item has_package($package)

Test if the package $package is installed.

=item has_file($file)

Test if the file $file is present.

=item has_service_running($service)

Test if the service $service is running.

=item has_service_stopped($service)

Test if the service $service is stopped.

=back

=cut

our $AUTOLOAD;

sub AUTOLOAD {
  my $self = shift or return undef;
  ( my $method = $AUTOLOAD ) =~ s{.*::}{};

  if ( $method eq "DESTROY" ) {
    return;
  }

  my $pkg = __PACKAGE__ . "::$method";
  eval "use $pkg";
  if ($@) {
    confess "Error loading $pkg. No such test method.";
  }

  my $p = $pkg->new;
  $p->run_test(@_);
}

1;
