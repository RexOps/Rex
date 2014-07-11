#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::FreeBSD;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  i_run("which pkg_add");
  if ( $? == 0 ) {
    $self->{commands} = {
      install         => 'pkg_add -r %s',
      install_version => 'pkg_add -r %s',
      remove          => 'pkg_delete %s',
      query           => 'pkg_info',
    };
  }
  else {
    $self->{commands} = {
      install         => 'pkg install -q -y %s',
      install_version => 'pkg install -q -y %s',
      remove          => 'pkg remove -y %s',
      query           => 'pkg info',
    };
  }

  return $self;
}

sub remove {
  my ( $self, $pkg ) = @_;

  my ($pkg_found) = grep { $_->{"name"} eq "$pkg" } $self->get_installed();
  my $pkg_version = $pkg_found->{"version"};

  return $self->SUPER::remove("$pkg-$pkg_version");
}

sub get_installed {
  my ($self) = @_;

  my @lines = i_run $self->{commands}->{query};

  my @pkg;

  for my $line (@lines) {
    my ( $pkg_name_v, $descr ) = split( /\s/, $line, 2 );

    my ( $pkg_name, $pkg_version ) = ( $pkg_name_v =~ m/^(.*)-(.*?)$/ );

    push(
      @pkg,
      {
        name    => $pkg_name,
        version => $pkg_version,
      }
    );
  }

  return @pkg;
}

1;
