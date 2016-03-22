#  OpenWrt.pm
#
#  Copyright 2013 Ferenc Erki <erkiferenc@gmail.com>
#
#  OpenWrt package management module for (R)?ex
#  based on Rex::Pkg::Debian

package Rex::Pkg::OpenWrt;

use strict;
use warnings;

# VERSION

use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    install           => 'opkg install %s',
    install_version   => 'opkg install %s',
    remove            => 'opkg remove %s',
    update_package_db => 'opkg update',
  };

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  delete $option->{version}; # makes no sense to specify the same version for several packages

  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub update_system {
  my ($self) = @_;
  my @pkgs;
  my @lines = i_run("opkg list-upgradable");

  for my $line (@lines) {
    if ( $line =~ m/^(.*) - .* - .*$/ ) { push( @pkgs, $1 ); }
  }

  my $packages_to_upgrade = join( " ", @pkgs );

  i_run( "opkg upgrade " . $packages_to_upgrade );
}

sub get_installed {
  my ( $self, $pkg ) = @_;
  my @pkgs;
  my $opkg_cmd = 'opkg list-installed';
  if ($pkg) {
    $opkg_cmd .= ' | grep "^' . $pkg . ' "';
  }

  my @lines = i_run $opkg_cmd;

  for my $line (@lines) {
    if ( $line =~ m/^(.*) - (.*)$/ ) {
      push(
        @pkgs,
        {
          name    => $1,
          version => $2,
        }
      );
    }
  }

  return @pkgs;
}

sub add_repository {
  my ( $self, %data ) = @_;
  append_if_no_such_line "/etc/opkg.conf",
    "src/gz " . $data{"name"} . " " . $data{"url"},
    $data{"name"},
    $data{"url"};
}

sub rm_repository {
  my ( $self, $name ) = @_;
  delete_lines_matching "/etc/opkg.conf" => "src/gz " . $name . " ";
}

1;
