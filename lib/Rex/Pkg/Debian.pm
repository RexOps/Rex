#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Debian;

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
    install =>
      'APT_LISTCHANGES_FRONTEND=text DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold -y install %s',
    install_version =>
      'APT_LISTCHANGES_FRONTEND=text DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold -y install %s=%s',
    update_system =>
      'APT_LISTCHANGES_FRONTEND=text DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade',
    remove            => 'apt-get -y remove %s',
    purge             => 'dpkg --purge %s',
    update_package_db => 'apt-get -y update',
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
  my @pkgs;
  my $dpkg_cmd =
    'dpkg-query -W --showformat "\${Status} \${Package}|\${Version}\n"';
  if ($pkg) {
    $dpkg_cmd .= " " . $pkg;
  }

  my @lines = i_run $dpkg_cmd;

  for my $line (@lines) {
    if ( $line =~ m/^install ok installed ([^\|]+)\|(.*)$/ ) {
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

  my $name = $data{"name"};

  my $fh = file_write "/etc/apt/sources.list.d/$name.list";
  $fh->write("# This file is managed by Rex\n");
  if ( exists $data{"arch"} ) {
    $fh->write( "deb [arch="
        . $data{"arch"} . "] "
        . $data{"url"} . " "
        . $data{"distro"} . " "
        . $data{"repository"}
        . "\n" );
  }
  else {
    $fh->write( "deb "
        . $data{"url"} . " "
        . $data{"distro"} . " "
        . $data{"repository"}
        . "\n" );
  }
  if ( exists $data{"source"} && $data{"source"} ) {
    $fh->write( "deb-src "
        . $data{"url"} . " "
        . $data{"distro"} . " "
        . $data{"repository"}
        . "\n" );
  }
  $fh->close;

  if ( exists $data{"key_url"} ) {
    i_run "wget -O - " . $data{"key_url"} . " | apt-key add -";
  }

  if ( exists $data{"key_id"} && $data{"key_server"} ) {
    i_run "apt-key adv --keyserver "
      . $data{"key_server"}
      . " --recv-keys "
      . $data{"key_id"};
  }
}

sub rm_repository {
  my ( $self, $name ) = @_;
  unlink "/etc/apt/sources.list.d/$name.list";
}

1;
