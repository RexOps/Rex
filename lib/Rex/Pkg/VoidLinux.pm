#
# (c) 2019 Leah Neukirchen <leah@vuxu.org>
# based on Rex::Pkg::Arch
# (c) Harm Müller <harm _DOT_ mueller _AT_ g m a i l _Dot_ com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::VoidLinux;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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

  if ( Rex::has_feature_version('1.5') ) {
    $self->{commands} = {
      install            => 'xbps-install -y %s',
      install_version    => 'xbps-install -y %s', # makes no sense to specify the package version
      update_system      => 'xbps-install -yu',
      dist_update_system => 'xbps-install -yu',
      remove             => 'xbps-remove -Ry %s',
      update_package_db  => 'xbps-install -S',
    };
  }
  else {
    $self->{commands} = {
      install            => 'xbps-install -y %s',
      install_version    => 'xbps-install -y %s', # makes no sense to specify the package version
      update_system      => 'xbps-install -Syu',
      dist_update_system => 'xbps-install -Syu',
      remove             => 'xbps-remove -Ry %s',
      update_package_db  => 'xbps-install -S',
    };
  }

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
  my ( @pkgs, $name, $version, $release, $arch );
  my $pkg_query = 'xbps-query --search=';
  if ( defined($pkg) ) {
    $pkg_query .= $pkg;
  }
  my @installed_packages = i_run $pkg_query;
  for my $line (@installed_packages) {
    if ( $line =~ /^\[\*\] ([^ ]*)-([^- ]*)_(\d+)/ ) {
      $name    = $1;
      $version = $2;
      $release = $3;
      push(
        @pkgs,
        {
          name    => $name,
          version => $version,
          release => $release,
        }
      );
    }
  }

  return @pkgs;
}

1;
