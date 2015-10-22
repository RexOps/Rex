#
# (c) Harm Müller <harm _DOT_ mueller _AT_ g m a i l _Dot_ com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Arch;

use strict;
use warnings;

# VERSION

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;

use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    install           => 'pacman --noprogressbar --noconfirm --needed -S %s',
    install_version   => 'pacman --noprogressbar --noconfirm --needed -S %s',     # makes no sense to specify the package version
    update_system     => 'pacman --noprogressbar --noconfirm -Syu',
    remove            => 'pacman --noprogressbar --noconfirm -Rs %s',
    purge             => 'pacman --noprogressbar --noconfirm -Rns %s',
    update_package_db => 'pacman --noprogressbar -Sy',
  };

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  delete $option->{version}; # makes no sense to specify the same version for several packages

  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub get_installed {
  my ( $self, $pkg ) = @_;
  my (@pkgs, $name, $version, $release, $arch);
  my $pkg_query = 'pacman -Qi  | egrep "^Name|^Version|^Architecture"';
  if ( defined($pkg) ) {
    $pkg_query .= " " . $pkg;
  }
  my @installed_packages = i_run $pkg_query;
  for my $line (@installed_packages) {
    if ( $line =~ m/^Name\s+:\s+([\S]+)$/ ) {
      $name = $1;
    }
    elsif ( $line =~ m/^Version\s+:\s+([\S]+)-([\S]+)$/ ) {
      $version = $1;
      $release = $2;
    }
    elsif ( $line =~ m/^Architecture\s+:\s+([\S]+)$/ ) {
      $arch = $1;
    }
    if ( defined($name) && defined($version) && defined($release) && defined($arch) ) {
      push(
        @pkgs,
        {
          name    => $name,
          version => $version,
          release => $release,
          arch    => $arch,
        }
      );
      $name = $version = $release = $arch = undef;
    }
  }


  return @pkgs;
}

sub add_repository {
  Rex::Logger::info("no suitable repo management use template/file for pacman.conf");
  return 1;
}

sub rm_repository {
  Rex::Logger::info("no suitable repo management use template/file for pacman.conf");
  return 1;
}

1;
