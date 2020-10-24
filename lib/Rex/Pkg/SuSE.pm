#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::SuSE;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Helper::Run;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  if ( Rex::has_feature_version('1.5') ) {
    $self->{commands} = {
      install            => 'zypper -n install %s',
      install_version    => 'zypper -n install $pkg-%s',
      update_system      => 'zypper -n --no-refresh up',
      dist_update_system => 'zypper -n --no-refresh up',
      remove             => 'zypper -n remove %s',
      update_package_db  => 'zypper -n ref -fd',
    };
  }
  else {
    $self->{commands} = {
      install            => 'zypper -n install %s',
      install_version    => 'zypper -n install $pkg-%s',
      update_system      => 'zypper -n up',
      dist_update_system => 'zypper -n up',
      remove             => 'zypper -n remove %s',
      update_package_db  => 'zypper --no-gpg-checks -n ref -fd',
    };
  }

  return $self;
}

sub bulk_install {
  my ( $self, $packages_aref, $option ) = @_;

  delete $option->{version}; # makes no sense to specify the same version for several packages

  $self->update( "@{$packages_aref}", $option );

  return 1;
}

sub get_installed {
  my ($self) = @_;

  my @lines = i_run
    'rpm -qa --nosignature --nodigest --qf "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"';

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
  i_run "zypper addrepo -f -n "
    . $data{"name"} . " "
    . $data{"url"} . " "
    . $data{"name"}, fail_ok => 1;
  if ( $? == 4 ) {
    if ( Rex::Config->get_do_reporting ) {
      return { changed => 0 };
    }
  }
  if ( $? != 0 ) {
    die( "Error adding repository " . $data{name} );
  }
}

sub rm_repository {
  my ( $self, $name ) = @_;
  i_run "zypper removerepo $name", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error removing repository $name");
  }

  if ( Rex::Config->get_do_reporting ) {
    return { changed => 1 };
  }
}

1;
