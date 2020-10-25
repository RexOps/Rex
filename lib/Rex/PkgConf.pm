#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::PkgConf;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Config;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Logger;

my %PKG_PROVIDER;

sub register_package_provider {
  my ( $class, $service_name, $service_class ) = @_;
  $PKG_PROVIDER{"\L$service_name"} = $service_class;
  return 1;
}

sub get {

  my ($self) = @_;

  my %_host = %{ Rex::Hardware::Host->get() };
  my $host  = {%_host};

  my $pkg_provider_for = Rex::Config->get("package_provider") || {};

  if ( is_redhat() ) {
    $host->{"operatingsystem"} = "Redhat";
  }
  elsif ( is_debian() ) {
    $host->{"operatingsystem"} = "Debian";
  }

  my $class = "Rex::PkgConf::" . $host->{"operatingsystem"};

  my $provider;
  if ( ref($pkg_provider_for)
    && exists $pkg_provider_for->{ $host->{"operatingsystem"} } )
  {
    $provider = $pkg_provider_for->{ $host->{"operatingsystem"} };
    $class .= "::$provider";
  }
  elsif ( exists $PKG_PROVIDER{$pkg_provider_for} ) {
    $class = $PKG_PROVIDER{$pkg_provider_for};
  }

  Rex::Logger::debug("Using $class for package management");
  eval "use $class";

  if ($@) {

    if ($provider) {
      Rex::Logger::info( "Provider not supported (" . $provider . ")" );
    }
    else {
      Rex::Logger::info(
        "OS not supported (" . $host->{"operatingsystem"} . ")" );
    }
    die("OS/Provider not supported");

  }

  return $class->new;

}

1;
