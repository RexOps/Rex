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

# VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub is_installed {

  my ( $self, $pkg, $option ) = @_;
  my $version = $option->{version};

  Rex::Logger::debug(
    "Checking if $pkg" . ( $version ? "-$version" : "" ) . " is installed" );

  my @pkg_info = grep { $_->{name} eq $pkg } $self->get_installed();
  @pkg_info = grep { $_->{version} eq $version } @pkg_info if defined $version;

  unless (@pkg_info) {
    Rex::Logger::debug(
      "$pkg" . ( $version ? "-$version" : "" ) . " is NOT installed." );
    return 0;
  }

  Rex::Logger::debug(
    "$pkg" . ( $version ? "-$version" : "" ) . " is installed." );
  return 1;

}

sub install {
  my ( $self, $pkg, $option ) = @_;

  if ( $self->is_installed( $pkg, $option ) ) {
    Rex::Logger::info("$pkg is already installed");
    return 1;
  }

  $self->update( $pkg, $option );

  return 1;
}

sub update {
  my ( $self, $pkg, $option ) = @_;

  my $version = $option->{'version'} || '';

  Rex::Logger::debug( "Installing $pkg" . ( $version ? "-$version" : "" ) );
  my $cmd = sprintf $self->{commands}->{install}, $pkg;

  if ( exists $option->{version} ) {
    $cmd = sprintf $self->{commands}->{install_version}, $pkg,
      $option->{version};
  }

  my ( $out, $err ) = i_run $cmd, sub { @_ };
  my @return = $self->test_return( 'update', $out, $err );

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error installing $pkg.", "warn" );
    Rex::Logger::debug($out);
    die("Error installing $pkg");
  }

  $self->_report_output( 'Running package update command', @return );
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
  my ( $out, $err ) = i_run $cmd, sub { @_ };
  my @return = $self->test_return( 'update_system', $out, $err );

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error updating system.", "warn" );
    Rex::Logger::debug($out);
    die("Error updating system");
  }

  $self->_report_output( 'Running update_system package command', @return );
  Rex::Logger::debug("System successfully updated.");

  return 1;
}

sub remove {
  my ( $self, $pkg ) = @_;

  Rex::Logger::debug("Removing $pkg");
  my $cmd = sprintf $self->{commands}->{remove}, $pkg;

  my ( $out, $err ) = i_run $cmd, sub { @_ };
  my @return = $self->test_return( 'update_pkg_db', $out, $err );

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error removing $pkg.", "warn" );
    Rex::Logger::debug($out);
    die("Error removing $pkg");
  }

  $self->_report_output( 'Running package remove command', @return );
  Rex::Logger::debug("$pkg successfully removed.");

  return 1;
}

sub purge {
  my ( $self, $pkg ) = @_;
  return 1 if ( !exists $self->{commands}->{purge} );
  Rex::Logger::debug("Purging $pkg");
  my $cmd = sprintf $self->{commands}->{purge}, $pkg;

  my ( $out, $err ) = i_run $cmd, sub { @_ };
  my @return = $self->test_return( 'update_pkg_db', $out, $err );

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error purging $pkg.", "warn" );
    Rex::Logger::debug($out);
    die("Error purging $pkg");
  }

  $self->_report_output( 'Running package purge command', @return );
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

  my ( $out, $err ) = i_run $cmd, sub { @_ };
  my @return = $self->test_return( 'update_pkg_db', $out, $err );

  if ( $? != 0 ) {
    die(
      "Running package database update command returned failure in exit status"
    );
  }

  $self->_report_output( 'Running package database update command', @return );
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

sub diff_package_list {
  my ( $self, $list1, $list2 ) = @_;

  my @old_installed = @{$list1};
  my @new_installed = @{$list2};

  my @modifications;

  # getting modifications of old packages
OLD_PKG:
  for my $old_pkg (@old_installed) {
  NEW_PKG:
    for my $new_pkg (@new_installed) {
      if ( $old_pkg->{name} eq $new_pkg->{name} ) {

        # flag the package as found in new package list,
        # to find removed and new ones.
        $old_pkg->{found} = 1;
        $new_pkg->{found} = 1;

        if ( $old_pkg->{version} ne $new_pkg->{version} ) {
          push @modifications, { %{$new_pkg}, action => 'updated' };
        }
        next OLD_PKG;
      }
    }
  }

  # getting removed old packages
  push @modifications, map { $_->{action} = 'removed'; $_ }
    grep { !exists $_->{found} } @old_installed;

  # getting new packages
  push @modifications, map { $_->{action} = 'installed'; $_ }
    grep { !exists $_->{found} } @new_installed;

  map { delete $_->{found} } @modifications;

  return @modifications;
}

sub test_return { }

sub _report_output {
  my ( $self, $description, $errors, $warnings, $debug ) = @_;
  Rex::Logger::info( "$description: $errors",   'error' ) if $errors;
  Rex::Logger::info( "$description: $warnings", 'warn' )  if $warnings;
  Rex::Logger::debug("$description: $debug") if $debug;
}

1;
