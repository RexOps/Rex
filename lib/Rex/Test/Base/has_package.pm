#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Test::Base::has_package;

use strict;
use warnings;

use Rex -base;
use base qw(Rex::Test::Base);
use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $pkg, $version ) = @_;
  if ($version) {
    my @packages = installed_packages;
    for my $p (@packages) {
      if ( $p->{name} eq $pkg ) {
        if ( $p->{version} eq $version ) {
          $self->ok( 1, "Found package $pkg in version $version." );
          return 1;
        }
      }
    }
  }
  else {
    if ( is_installed($pkg) ) {
      $self->ok( 1, "Found package $pkg" );
      return 1;
    }
  }

  $self->ok( 0,
    "Found package $pkg" . ( $version ? " in version $version" : "" ) );

  return 0;
}

1;
