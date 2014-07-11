#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Gentoo;

use strict;
use warnings;

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
    install           => 'emerge %s',
    install_version   => 'emerge =%s-%s',
    update_system     => 'emerge --update --deep --with-bdeps=y --newuse world',
    remove            => 'emerge -C %s',
    update_package_db => 'emerge --sync',
  };

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  delete $option->{version}
    ;    # makes no sense to specify the same version for several packages

  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub get_installed {
  my ($self) = @_;

  # ,,stolen'' from epm
  my $pkgregex = '(.+?)' .                     # name
    '-(\d+(?:\.\d+)*\w*)' .                    # version, eg 1.23.4a
    '((?:(?:_alpha|_beta|_pre|_rc)\d*)?)' .    # special suffix
    '((?:-r\d+)?)$';                           # revision, eg r12

  my @ret;

  for my $line ( i_run("ls -d /var/db/pkg/*/* | cut -d '/' -f6-") ) {
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

  my $name = $data{"name"};

  if ( can_run("layman") ) {
    i_run "layman -a $name";
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
