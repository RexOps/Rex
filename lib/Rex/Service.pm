#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Service;

use v5.14.4;
use warnings;
use strict;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Config;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Hardware::Host;
use Rex::Helper::Run;
use Rex::Logger;

use Class::Load;

my %SERVICE_PROVIDER;

sub register_service_provider {
  my ( $class, $service_name, $service_class ) = @_;
  $SERVICE_PROVIDER{"\L$service_name"} = $service_class;
  return 1;
}

## no critic (ProhibitExcessComplexity, ProhibitCascadingIfElse)

sub get {

  my $operatingsystem = Rex::Hardware::Host->get_operating_system();

  my $r = i_run 'systemctl --no-pager > /dev/null', fail_ok => 1;
  my $can_run_systemctl = $r == 0 ? 1 : 0;

  $r = i_run 'initctl version | grep upstart', fail_ok => 1;
  my $running_upstart = $r == 0 ? 1 : 0;

  my $class;

  $class = 'Rex::Service::' . $operatingsystem;
  if ( is_redhat($operatingsystem) && $can_run_systemctl ) {
    $class = 'Rex::Service::Redhat::systemd';
  }
  elsif ( is_redhat($operatingsystem) ) {

    # this also counts for fedora, centos, ...
    $class = 'Rex::Service::Redhat';
  }
  elsif ( is_suse($operatingsystem) && $can_run_systemctl ) {
    $class = 'Rex::Service::SuSE::systemd';
  }
  elsif ( is_alt($operatingsystem) && $can_run_systemctl ) {
    $class = 'Rex::Service::ALT::systemd';
  }
  elsif ( is_gentoo($operatingsystem) && $can_run_systemctl ) {
    $class = 'Rex::Service::Gentoo::systemd';
  }
  elsif ( is_gentoo($operatingsystem) ) {
    $class = 'Rex::Service::Gentoo';
  }
  elsif ( is_mageia($operatingsystem) && $can_run_systemctl ) {
    $class = 'Rex::Service::Mageia::systemd';
  }
  elsif ( is_debian($operatingsystem) && $can_run_systemctl ) {

    # this also counts for Ubuntu and LinuxMint
    $class = 'Rex::Service::Debian::systemd';
  }
  elsif ( is_debian($operatingsystem) && $running_upstart ) {

    # this is mainly Ubuntu with upstart
    $class = 'Rex::Service::Ubuntu';
  }
  elsif ( is_debian($operatingsystem) ) {
    $class = 'Rex::Service::Debian';
  }
  elsif ( is_arch($operatingsystem) && $can_run_systemctl ) {
    $class = 'Rex::Service::Arch::systemd';
  }
  elsif ( is_alpine($operatingsystem) ) {
    $class = 'Rex::Service::Alpine';
  }
  elsif ( is_voidlinux($operatingsystem) ) {
    $class = 'Rex::Service::VoidLinux';
  }

  my $provider_for = Rex::Config->get('service_provider') || {};
  my $provider;

  if ( ref($provider_for) && exists $provider_for->{$operatingsystem} ) {
    $provider = $provider_for->{$operatingsystem};
    $class .= "::\L$provider";
  }
  elsif ( exists $SERVICE_PROVIDER{$provider_for} ) {
    $class = $SERVICE_PROVIDER{$provider_for};
  }

  Rex::Logger::debug("service using class: $class");

  # eval "use $class" = will no work!

  if ( !Class::Load::is_class_loaded($class) ) {
    Rex::Logger::info("OS ($operatingsystem) not supported");
    exit 1;
  }

  return $class->new;

}

## use critic

1;
