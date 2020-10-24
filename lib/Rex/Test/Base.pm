#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Test::Base - Basic Test Module

=head1 DESCRIPTION

This is a basic test module to test your code with the help of local VMs. You can place your tests in the "t" directory.

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

=cut

package Rex::Test::Base;

use 5.010001;
use strict;
use warnings;

use base 'Test::Builder::Module';

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Commands;
use Rex::Commands::Box;
use Data::Dumper;
use Carp;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(test);

=head2 new(name => $test_name)

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
  $self->{memory} ||= 512; # default, in MB
  $self->{cpu}    ||= 1;   # default

  return $self;
}

=head2 name($name)

The name of the test. A VM called $name will be created for each test. If the VM already exists, Rex will try to reuse it.

=cut

sub name {
  my ( $self, $name ) = @_;
  $self->{name} = $name;
}

=head2 memory($amount)

The amount of memory the VM should use, in Megabytes.

=cut

sub memory {
  my ( $self, $memory ) = @_;
  $self->{memory} = $memory;
}

=head2 cpus($number)

The number of CPUs the VM should use.

=cut

sub cpus {
  my ( $self, $cpus ) = @_;
  $self->{cpus} = $cpus;
}

=head2 vm_auth(%auth)

Authentication options for the VM. It accepts the same parameters as C<Rex::Box::Base-E<gt>auth()>.

=cut

sub vm_auth {
  my ( $self, %auth ) = @_;
  $self->{auth} = \%auth;
}

=head2 base_vm($vm)

The URL to a base image to be used for the test VM.

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

=head2 redirect_port($port)

Redirect local $port to the VM's SSH port (default: 2222).

=cut

sub redirect_port {
  my ( $self, $port ) = @_;
  $self->{redirect_port} = $port;
}

=head2 run_task($task)

The task to run on the test VM. You can run multiple tasks by passing an array reference.

=cut

sub run_task {
  my ( $self, $task ) = @_;

  # allow multiple calls to run_task() without setting up new box
  if ( $self->{box} ) {
    $self->{box}->provision_vm($task);
    return;
  }

  my $box;
  box {
    $box = shift;
    $box->name( $self->{name} );
    $box->url( $self->{vm} );
    $box->memory( $self->{memory} );
    $box->cpus( $self->{cpus} );

    $box->network(
      1 => {
        type => "nat",
      }
    );

    $box->forward_port( ssh => [ $self->{redirect_port}, 22 ] );

    $box->auth( %{ $self->{auth} } );

    if ( ref $task eq 'ARRAY' ) {
      $box->setup(@$task);
    }
    else {
      $box->setup($task);
    }
  };

  $self->{box} = $box;

  # connect to the machine
  Rex::connect(
    server => $box->ip,
    %{ $self->{auth} },
  );
}

sub ok() {
  my ( $self, $test, $msg ) = @_;
  my $tb = Rex::Test::Base->builder;
  $tb->ok( $test, $msg );
}

sub like {
  my ( $self, $thing, $want, $name ) = @_;
  my $tb = Rex::Test::Base->builder;
  $tb->like( $thing, $want, $name );
}

sub diag {
  my ( $self, $msg ) = @_;
  my $tb = Rex::Test::Base->builder;
  $tb->diag($msg);
}

sub finish {
  my $tb = Rex::Test::Base->builder;
  $tb->done_testing();
  $tb->is_passing()
    ? print "PASS\n"
    : print "FAIL\n";
  if ( !$tb->is_passing() ) {
    Rex::Test::push_exit("FAIL");
  }
  $tb->reset();

  Rex::pop_connection();
}

=head1 TEST METHODS

=head2 has_content($file, $regexp)

Test if the content of $file matches against $regexp.

=head2 has_dir($path)

Test if $path is present and is a directory.

=head2 has_file($file)

Test if $file is present.

=head2 has_package($package, $version)

Test if $package is installed, optionally at $version.

=head2 has_service_running($service)

Test if $service is running.

=head2 has_service_stopped($service)

Test if $service is stopped.

=head2 has_stat($file, $stat)

Test if $file has properties described in hash reference $stat. List of supported checks:

=over 4

=item group

=item owner

=back

=cut

our $AUTOLOAD;

sub AUTOLOAD {
  my $self = shift or return;
  ( my $method = $AUTOLOAD ) =~ s{.*::}{};

  if ( $method eq "DESTROY" ) {
    return;
  }

  my $real_method = $method;
  my $is_not      = 0;
  if ( $real_method =~ m/^has_not_/ ) {
    $real_method =~ s/^has_not_/has_/;
    $is_not = 1;
  }

  my $pkg = __PACKAGE__ . "::$real_method";
  eval "use $pkg";
  if ($@) {
    confess "Error loading $pkg. No such test method.";
  }

  my $p = $pkg->new;
  if ($is_not) {
    $p->run_not_test(@_);
  }
  else {
    $p->run_test(@_);
  }
}

1;
