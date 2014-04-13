#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::SunOS::pkg;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Pkg::SunOS;

use base qw(Rex::Pkg::SunOS);

sub new {
  my $that = shift;
  my $proto = ref($that) || $that;
  my $self = { @_ };

  bless($self, $proto);

  return $self;
}

sub is_installed {
  my ($self, $pkg) = @_;

  Rex::Logger::debug("Checking if $pkg is installed");

  i_run("pkg info $pkg");

  unless($? == 0) {
    Rex::Logger::debug("$pkg is NOT installed.");
    return 0;
  }
  
  Rex::Logger::debug("$pkg is installed.");
  return 1;
}

sub install {
  my ($self, $pkg, $option) = @_;

  if($self->is_installed($pkg) && ! $option->{"version"}) {
    Rex::Logger::info("$pkg is already installed");
    return 1;
  }

  return 1;
}

sub update {
  my ($self, $pkg, $option) = @_;

  my $version = $option->{'version'} || '';

  Rex::Logger::debug("Installing $pkg");
  my $f = i_run "pkg install -q --accept $pkg";

  unless($? == 0) {
    Rex::Logger::info("Error installing $pkg.", "warn");
    Rex::Logger::debug($f);
    die("Error installing $pkg");
  }

  Rex::Logger::debug("$pkg successfully installed.");


  return 1;
}

sub remove {
  my ($self, $pkg) = @_;

  Rex::Logger::debug("Removing $pkg");
  my $f = i_run("pkg uninstall -r -q $pkg");

  unless($? == 0) {
    Rex::Logger::info("Error removing $pkg.", "warn");
    Rex::Logger::debug($f);
    die("Error removing $pkg");
  }

  Rex::Logger::debug("$pkg successfully removed.");

  return 1;
}


sub get_installed {
  my ($self) = @_;

  my @lines = i_run "pkg info -l";

  my @pkg;

  my ($version, $name);
  for my $line (@lines) {
    if($line =~ m/^$/) {
      push(@pkg, {
        name => $name,
        version => $version,
      });
      next;
    }

    if($line =~ m/Name: .*\/(.*?)$/) {
      $name = $1;
      next;
    }

    if($line =~ m/Version: (.*)$/) {
      $version = $1;
      next;
    }
  }

  return @pkg;
}

sub update_pkg_db {
  my ($self) = @_;

  i_run "pkg refresh";
  if($? != 0) {
    die("Error updating package database");
  }
}

1;
