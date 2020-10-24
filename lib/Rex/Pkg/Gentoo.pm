#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Gentoo;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Commands::Run;
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
    install         => 'emerge --update --changed-use %s',
    install_version => 'emerge --update --changed-use =%s-%s',
    reinstall_check =>
      'emerge --pretend --update --changed-use --nodeps --quiet --verbose =%s',
    update_system => 'emerge --update --deep --with-bdeps=y --newuse world',
    dist_update_system =>
      'emerge --update --deep --with-bdeps=y --newuse world',
    remove            => 'emerge -C %s',
    update_package_db => 'emerge --sync',
  };

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  delete $option->{version}; # makes no sense to specify the same version for several packages

  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub is_installed {

  my ( $self, $pkg, $option ) = @_;
  my $slot;
  my $version = $option->{version};

  # Determine slot.
  my $slot_idx = index( $pkg, ':' );
  if ( $slot_idx != -1 ) {
    die
      "Illegal package spec. `$pkg-$version': Both package and version has SLOT"
      if $version && index( $version, ':' ) != -1;
    $slot = substr( $pkg, $slot_idx + 1 );
    substr( $pkg, $slot_idx ) = '';
  }
  elsif ($version) {
    $slot_idx = index( $version, ':' );
    if ( $slot_idx != -1 ) {
      $slot = substr( $version, $slot_idx + 1 );
      substr( $version, $slot_idx ) = '';
    }
  }

  $self->{short} = 0;
  Rex::Logger::debug( "Checking if $pkg"
      . ( $version ? "-$version" : "" )
      . ( $slot    ? ":$slot"    : '' )
      . " is installed" );

  my @pkg_info = grep { $_->{name} eq $pkg } $self->get_installed();
  @pkg_info = grep { $_->{version} eq $version } @pkg_info if defined $version;

  unless (@pkg_info) {
    Rex::Logger::debug(
      "Couldn't find package by category/packagename, trying with packagename only"
    );
    $self->{short} = 1;
    @pkg_info      = grep { $_->{name} eq $pkg } $self->get_installed();
    @pkg_info      = grep { $_->{version} eq $version } @pkg_info
      if defined $version;
  }

  unless (@pkg_info) {
    Rex::Logger::debug( "$pkg"
        . ( $version ? "-$version" : "" )
        . ( $slot    ? ":$slot"    : '' )
        . " is NOT installed." );
    return 0;
  }

  # Check for requested SLOT.
  my $pkg_atom;

  if ( defined $slot ) {
    my $slot_ok;

    for my $info (@pkg_info) {
      $pkg_atom =
        "$info->{name}-$info->{version}$info->{suffix}$info->{release}";

      my $fh = file_read("/var/db/pkg/$pkg_atom/SLOT");
      chomp( my $slot_installed = $fh->read_all );
      $fh->close;

      if ( $slot eq $slot_installed ) {
        $pkg_atom .= ":$slot";
        $slot_ok = 1;
        last;
      }
    }

    unless ($slot_ok) {
      Rex::Logger::debug( "$pkg"
          . ( $version ? "-$version" : "" )
          . ( $slot    ? ":$slot"    : '' )
          . " is NOT installed." );
      return 0;
    }
  }
  else {
    $pkg_atom =
      "$pkg_info[0]->{name}-$pkg_info[0]->{version}$pkg_info[0]->{suffix}$pkg_info[0]->{release}";
  }

  # Check for any USE flag changes.
  my $rchk_cmd = sprintf( $self->{commands}->{reinstall_check}, $pkg_atom );
  my @rchk_out = i_run $rchk_cmd;

  for my $line (@rchk_out) {
    next unless $line =~ /\s*\[ebuild[^]]+\]\s+$pkg_info[0]->{name}/;

    Rex::Logger::debug( "$pkg"
        . ( $version ? "-$version" : "" )
        . ( $slot    ? ":$slot"    : '' )
        . " is installed but USE flags have changed." );
    return 0;
  }

  Rex::Logger::debug( "$pkg"
      . ( $version ? "-$version" : "" )
      . ( $slot    ? ":$slot"    : '' )
      . " is installed." );
  return 1;

}

sub get_installed {
  my ($self) = @_;
  my $cut_cmd;
  if ( $self->{short} ) {
    $cut_cmd = "cut -d '/' -f6-";
  }
  else {
    $cut_cmd = "cut -d '/' -f5-";
  }

  # ,,stolen'' from epm
  my $pkgregex = '(.+?)' .                  # name
    '-(\d+(?:\.\d+)*\w*)' .                 # version, eg 1.23.4a
    '((?:(?:_alpha|_beta|_pre|_rc)\d*)?)' . # special suffix
    '((?:-r\d+)?)$';                        # revision, eg r12

  my @ret;

  for my $line ( i_run("ls -d /var/db/pkg/*/* | $cut_cmd") ) {
    my $r = qr{$pkgregex};
    my ( $name, $version, $suffix, $revision ) = ( $line =~ $r );
    push(
      @ret,
      {
        name    => $name,
        version => $version,
        suffix  => $suffix,
        release => $revision,
      }
    );
  }

  return @ret;
}

sub add_repository {
  my ( $self, %data ) = @_;

  my $name  = $data{"name"};
  my $readd = $data{"readd"} // 0;

  if ( can_run("layman") ) {
    my $op;

    i_run "layman -lqnN | grep -q '$name'", fail_ok => 1;
    if ( $? == 0 ) {
      if ($readd) {
        $op = 'r'; # --readd
      }
      else {
        Rex::Logger::info(
          "Repository $name is present, use `readd' option to re-add from scratch."
        );
      }
    }
    else {
      $op = 'a';   # --add
    }
    i_run "layman -$op $name" if defined $op;
  }
  else {
    Rex::Logger::debug("You have to install layman, git and subversion.");
    die("Please install layman, git and subversion");
  }
}

sub rm_repository {
  my ( $self, $name ) = @_;

  if ( can_run("layman") ) {
    i_run "layman -d $name";
  }
  else {
    Rex::Logger::debug("You have to install layman, git and subversion.");
    die("Please install layman, git and subversion");
  }
}

1;
