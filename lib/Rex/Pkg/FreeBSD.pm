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

  # Check if pkg is actually bootstraped (installed and activated)
  i_run "pkg -N";
  if ( $? != 0 ) {
    i_run "pkg bootstrap", env => { 'ASSUME_ALWAYS_YES' => 'true' };
  }

  $self->{commands} = {
    install           => 'pkg install -q -y %s',
    install_version   => 'pkg install -q -y %s',
    remove            => 'pkg remove -q -y %s',
    query             => 'pkg info',
    update_package_db => 'pkg update -q',

    # pkg can't update system yet, only packages
    update_system => 'pkg upgrade -q -y',
  };

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  # makes no sense to specify the same version for several packages
  delete $option->{version};
  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub remove {
  my ( $self, $pkg ) = @_;

  my ($pkg_found) = grep { $_->{"name"} eq "$pkg" } $self->get_installed();
  my $pkg_version = $pkg_found->{"version"};

  return $self->SUPER::remove("$pkg-$pkg_version");
}

sub is_installed {
  my ( $self, $pkg ) = @_;

  Rex::Logger::debug("Checking if $pkg is installed");

  # pkg info -e allow get quick answer about is pkg installed or not.
  my $command = sprintf( $self->{commands}->{query} . " %s %s", '-e', $pkg );
  i_run $command;

  if ( $? != 0 ) {
    Rex::Logger::debug("$pkg is NOT installed.");
    return 0;
  }

  Rex::Logger::debug("$pkg is installed.");
  return 1;

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
