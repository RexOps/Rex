#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Gentoo;

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
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub is_installed {
  my ( $self, $pkg ) = @_;

  Rex::Logger::debug("Checking if $pkg is installed");

  unless ( grep { $_->{"name"} eq $pkg } get_installed() ) {
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

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  delete $option->{version}
    ;    # makes no sense to specify the same version for several packages

  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub update {
  my ( $self, $pkg, $option ) = @_;

  my $version = $option->{'version'} || '';
  if ($version) {
    $pkg = "=$pkg-$version";
  }

  Rex::Logger::debug("Installing $pkg / $version");
  my $f = i_run("emerge $pkg");

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error installing $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error installing $pkg");
  }

  Rex::Logger::debug("$pkg successfully installed.");

  return 1;
}

sub remove {
  my ( $self, $pkg ) = @_;

  Rex::Logger::debug("Removing $pkg");
  my $f = i_run("emerge -C $pkg");

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error removing $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error removing $pkg");
  }

  Rex::Logger::debug("$pkg successfully removed.");

  return 1;
}

sub get_installed {
  my ($self) = @_;

  # ,,stolen'' from epm
  my $pkgregex = '(.+?)' .                     # name
    '-(\d+(?:\.\d+)*\w*)' .                    # version, eg 1.23.4a
    '((?:(?:_alpha|_beta|_pre|_rc)\d*)?)' .    # special suffix
    '((?:-r\d+)?)$';                           # revision, eg r12

  my @ret;

  for my $line ( i_run("ls -d /var/db/pkg/*/* | cut -d '/' -f6-") ) {
    my $r = qr{$pkgregex};
    my ( $name, $version, $suffix, $revision ) = ( $line =~ $r );
    push(
      @ret,
      {
        name    => $name,
        version => $version,
        suffix  => $suffix,
        release => $revision,
      }
    );
  }

  return @ret;
}

sub update_system {
  my ($self) = @_;
  i_run "emerge --update --deep --with-bdeps=y --newuse world";
}

sub update_pkg_db {
  my ($self) = @_;

  i_run "emerge --sync";
  if ( $? != 0 ) {
    die("Error updating package database");
  }
}

sub add_repository {
  my ( $self, %data ) = @_;

  my $name = $data{"name"};

  if ( can_run("layman") ) {
    i_run "layman -a $name";
  }
  else {
    Rex::Logger::debug("You have to install layman, git and subversion.");
    die("Please install layman, git and subversion");
  }
}

sub rm_repository {
  my ( $self, $name ) = @_;

  if ( can_run("layman") ) {
    i_run "layman -d $name";
  }
  else {
    Rex::Logger::debug("You have to install layman, git and subversion.");
    die("Please install layman, git and subversion");
  }
}

1;
