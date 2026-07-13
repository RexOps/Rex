#
# (c) Pieter le Roux <pgp@myleroux.net>
#

package Rex::Pkg::Alpine;

use v5.14.4;
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

  bless $self, $proto;

  $self->{commands} = {
    install           => '/sbin/apk -q add %s',
    update_system     => '/sbin/apk -q upgrade',
    remove            => '/sbin/apk -q del %s',
    update_package_db => '/sbin/apk -q update',
    install_version   => '/sbin/apk -q add %s=%s',
    purge             => '/sbin/apk -q --purge %s',
  };

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  $self->update("@{$packages_aref}");

  return 1;
}

sub get_installed {
  my ( $self, $pkg ) = @_;
  my @pkgs;
  my $cmd = 'apk -I list';
  if ($pkg) {
    $cmd .= " $pkg";
  }

  my @lines = i_run $cmd;

  foreach my $line (@lines) {
    my ( $xname, $arch ) = split /\s/sxm, $line;
    if ( $xname =~ /^(.+)-(\d.+)/sxm ) {
      push @pkgs,
        {
        name         => $1,
        version      => $2,
        architecture => $arch,
        };
    }
  }

  return @pkgs;
}

1;

