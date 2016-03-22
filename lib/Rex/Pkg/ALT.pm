#
# Work with ALT Linux APT-RPM package management system
#

package Rex::Pkg::ALT;

use strict;
use warnings;

# VERSION

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
    install           => '/usr/bin/apt-get -y install %s',
    install_version   => '/usr/bin/apt-get -y install %s-%s',
    remove            => '/usr/bin/apt-get -y remove %s',
    update_package_db => '/usr/bin/apt-get update',
  };

  return $self;
}

sub get_installed {
  my ($self) = @_;

  my @lines = i_run
    '/usr/bin/rpm -qa --nodigest --qf "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"';

  my @pkg;

  for my $line (@lines) {
    if ( $line =~ m/^([^\s]+)\s([^\s]+)\s([^\s]+)\s([^\s]+)\s(.*)$/ ) {
      push(
        @pkg,
        {
          name    => $1,
          epoch   => $2,
          version => $3,
          release => $4,
          arch    => $5,
        }
      );
    }
  }

  return @pkg;
}

sub add_repository {
  my ( $self, %data ) = @_;
  my $name = $data{"name"};
  my $sign = $data{"sign_key"} || "";
  my @arch = split( /, */, $data{"arch"} );

  my $fh = file_write "/etc/apt/sources.list.d/$name.list";
  $fh->write("# This file is managed by Rex\n");

  foreach (@arch) {
    $fh->write( "rpm "
        . ( $sign ? "[" . $sign . "] " : "" )
        . $data{"url"} . " "
        . $_ . " "
        . $data{"repository"}
        . "\n" );
  }
  $fh->close;
}

sub rm_repository {
  my ( $self, $name ) = @_;
  unlink "/etc/apt/sources.list.d/$name.list";
}

1;
