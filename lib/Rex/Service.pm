#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Service;

use strict;
use warnings;

# VERSION

use Rex::Config;
use Rex::Commands::Run;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Helper::Run;
use Rex::Logger;

my %SERVICE_PROVIDER;

sub register_service_provider {
  my ( $class, $service_name, $service_class ) = @_;
  $SERVICE_PROVIDER{"\L$service_name"} = $service_class;
  return 1;
}

sub get {

  my $operatingsystem = Rex::Hardware::Host->get_operating_system();

  i_run "systemctl --no-pager > /dev/null";
  my $can_run_systemctl = $? == 0 ? 1 : 0;

  my $class;

  $class = "Rex::Service::" . $operatingsystem;
  if ( is_redhat($operatingsystem) && $can_run_systemctl ) {
    $class = "Rex::Service::Redhat::systemd";
  }
  elsif ( is_redhat($operatingsystem) ) {

    # this also counts for fedora, centos, ...
    $class = "Rex::Service::Redhat";
  }
  elsif ( is_suse($operatingsystem) && $can_run_systemctl ) {
    $class = "Rex::Service::SuSE::systemd";
  }
  elsif ( is_alt($operatingsystem) && $can_run_systemctl ) {
    $class = "Rex::Service::ALT::systemd";
  }
  elsif ( is_gentoo($operatingsystem) && $can_run_systemctl ) {
    $class = "Rex::Service::Gentoo::systemd";
  }
  elsif ( is_mageia($operatingsystem) && $can_run_systemctl ) {
    $class = "Rex::Service::Mageia::systemd";
  }
  elsif ( is_debian($operatingsystem) && $can_run_systemctl ) {

    # this also counts for Ubuntu and LinuxMint
    $class = "Rex::Service::Debian::systemd";
  }
  elsif ( is_debian($operatingsystem) ) {
    $class = "Rex::Service::Debian";
  }
  elsif ( is_arch($operatingsystem) && $can_run_systemctl ) {
    $class = "Rex::Service::Arch::systemd";
  }

  my $provider_for = Rex::Config->get("service_provider") || {};
  my $provider;

  if ( ref($provider_for) && exists $provider_for->{$operatingsystem} ) {
    $provider = $provider_for->{$operatingsystem};
    $class .= "::\L$provider";
  }
  elsif ( exists $SERVICE_PROVIDER{$provider_for} ) {
    $class = $SERVICE_PROVIDER{$provider_for};
  }

  Rex::Logger::debug("service using class: $class");
  eval "use $class";

  if ($@) {

    Rex::Logger::info("OS ($operatingsystem) not supported");
    exit 1;

  }

  return $class->new;

}

1;
