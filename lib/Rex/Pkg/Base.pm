#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Base;

use strict;
use warnings;
use Rex::Helper::Run;
use Rex::Interface::Exec;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub is_installed {

  my ( $self, $pkg ) = @_;

  Rex::Logger::debug("Checking if $pkg is installed");

  my @pkg_info = $self->get_installed($pkg);

  unless (@pkg_info) {
    Rex::Logger::debug("$pkg is NOT installed.");
    return 0;
  }

  Rex::Logger::debug("$pkg is installed.");
  return 1;

}

sub install {
  my ( $self, $pkg, $option ) = @_;

  if ( $self->is_installed($pkg) && !$option->{"version"} ) {
    Rex::Logger::info("$pkg is already installed");
    return 1;
  }

  $self->update( $pkg, $option );

  return 1;
}

sub update {
  my ( $self, $pkg, $option ) = @_;

  my $version = $option->{'version'} || '';

  Rex::Logger::debug("Installing $pkg / $version");
  my $cmd = sprintf $self->{commands}->{install}, $pkg;

  if ( exists $option->{version} ) {
    $cmd = sprintf $self->{commands}->{install_version}, $pkg,
      $option->{version};
  }

  my $f = i_run $cmd;

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error installing $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error installing $pkg");
  }

  Rex::Logger::debug("$pkg successfully installed.");

  return 1;
}

sub update_system {
  my ($self) = @_;

  if ( !exists $self->{commands}->{update_system} ) {
    Rex::Logger::debug("Not supported under this OS");
    return;
  }

  my $cmd = $self->{commands}->{update_system};
  i_run $cmd;
}

sub remove {
  my ( $self, $pkg ) = @_;

  Rex::Logger::debug("Removing $pkg");
  my $cmd = sprintf $self->{commands}->{remove}, $pkg;

  my $f = i_run $cmd;

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error removing $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error removing $pkg");
  }

  Rex::Logger::debug("$pkg successfully removed.");

  return 1;
}

sub purge {
  my ( $self, $pkg ) = @_;
  return 1 if ( !exists $self->{commands}->{purge} );
  Rex::Logger::debug("Purging $pkg");
  my $cmd = sprintf $self->{purge}, $pkg;

  my $f = i_run $cmd;

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error purging $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error purging $pkg");
  }

  Rex::Logger::debug("$pkg successfully purged.");

  return 1;
}

sub update_pkg_db {
  my ($self) = @_;

  if ( !exists $self->{commands}->{update_package_db} ) {
    Rex::Logger::debug("Not supported under this OS");
    return;
  }

  my $cmd = $self->{commands}->{update_package_db};
  i_run $cmd;
  if ( $? != 0 ) {
    die("Error updating package database");
  }
}

sub bulk_install {
  Rex::Logger::info(
    "Installing bulk packages not supported on this platform. Falling back to one by one method",
    "warn"
  );

  my ( $self, $packages_aref, $option ) = @_;
  for my $pkg_to_install ( @{$packages_aref} ) {
    $self->install( $pkg_to_install, $option );
  }

  return 1;
}

sub add_repository {
  my ( $self, %data ) = @_;
  Rex::Logger::debug("Not supported under this OS");
}

sub rm_repository {
  my ( $self, $name ) = @_;
  Rex::Logger::debug("Not supported under this OS");
}

1;
