#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Debian;

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

  my $env =
    'APT_LISTBUGS_FRONTEND=none APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive';

  $self->{commands} = {
    install => "$env apt-get -o Dpkg::Options::=--force-confold -y install %s",
    install_version =>
      "$env apt-get -o Dpkg::Options::=--force-confold -y install %s=%s",
    update_system      => "$env apt-get -y -qq upgrade",
    dist_update_system => "$env apt-get -y -qq dist-upgrade",
    remove             => "$env apt-get -y remove %s",
    purge              => "$env dpkg --purge %s",
    update_package_db  => "$env apt-get -y update",
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
    'dpkg-query -W --showformat "\${Status} \${Package}|\${Version}|\${Architecture}\n"';
  if ($pkg) {
    $dpkg_cmd .= " " . $pkg;
  }

  my @lines = i_run $dpkg_cmd;

  for my $line (@lines) {
    if ( $line =~ m/^install ok installed ([^\|]+)\|([^\|]+)\|(.*)$/ ) {
      push(
        @pkgs,
        {
          name         => $1,
          version      => $2,
          architecture => $3,
        }
      );
    }
  }

  return @pkgs;
}

sub diff_package_list {
  my ( $self, $list1, $list2 ) = @_;

  my @old_installed = @{$list1};
  my @new_installed = @{$list2};

  my @modifications;

  # getting modifications of old packages
OLD_PKG:
  for my $old_pkg (@old_installed) {
  NEW_PKG:
    for my $new_pkg (@new_installed) {
      if ( $old_pkg->{name} eq $new_pkg->{name}
        && $old_pkg->{architecture} eq $new_pkg->{architecture} )
      {

        # flag the package as found in new package list,
        # to find removed and new ones.
        $old_pkg->{found} = 1;
        $new_pkg->{found} = 1;

        if ( $old_pkg->{version} ne $new_pkg->{version} ) {
          push @modifications, { %{$new_pkg}, action => 'updated' };
        }
        next OLD_PKG;
      }
    }
  }

  # getting removed old packages
  push @modifications, map { $_->{action} = 'removed'; $_ }
    grep { !exists $_->{found} } @old_installed;

  # getting new packages
  push @modifications, map { $_->{action} = 'installed'; $_ }
    grep { !exists $_->{found} } @new_installed;

  map { delete $_->{found} } @modifications;

  return @modifications;
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

  if ( exists $data{"key_file"} ) {
    i_run "apt-key add $data{'key_file'}";
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
