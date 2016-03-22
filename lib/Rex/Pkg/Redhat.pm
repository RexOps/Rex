#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Redhat;

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

  if ( Rex::has_feature_version('1.5') ) {
    $self->{commands} = {
      install            => $self->_yum('-y install %s'),
      install_version    => $self->_yum('-y install %s-%s'),
      update_system      => $self->_yum("-y -C upgrade"),
      dist_update_system => $self->_yum("-y -C upgrade"),
      remove             => $self->_yum('-y erase %s'),
      update_package_db  => $self->_yum("clean all") . " ; "
        . $self->_yum("makecache"),
    };
  }
  else {
    $self->{commands} = {
      install            => $self->_yum('-y install %s'),
      install_version    => $self->_yum('-y install %s-%s'),
      update_system      => $self->_yum("-y upgrade"),
      dist_update_system => $self->_yum("-y upgrade"),
      remove             => $self->_yum('-y erase %s'),
      update_package_db  => $self->_yum("clean all") . " ; "
        . $self->_yum("makecache"),
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

  my $name = $data{"name"};
  my $desc = $data{"description"} || $data{"name"};

  if ( exists $data{"key_url"} ) {
    i_run "rpm --import $data{key_url}";
  }

  if ( exists $data{"key_file"} ) {
    i_run "rpm --import $data{key_file}";
  }

  my $fh = file_write "/etc/yum.repos.d/$name.repo";

  $fh->write("# This file is managed by Rex\n");
  $fh->write("[$name]\n");
  $fh->write("name=$desc\n");
  $fh->write( "baseurl=" . $data{"url"} . "\n" );
  $fh->write("enabled=1\n");
  $fh->write( "gpgkey=" . $data{"gpgkey"} . "\n" )
    if defined $data{"gpgkey"};
  $fh->write( "gpgcheck=" . $data{"gpgcheck"} . "\n" )
    if defined $data{"gpgcheck"};

  $fh->close;
}

sub rm_repository {
  my ( $self, $name ) = @_;
  unlink "/etc/yum.repos.d/$name.repo";
}

sub _yum {
  my ( $self, @cmd ) = @_;

  my $str;

  if ($Rex::Logger::debug) {
    $str = join( ' ', "yum ", @cmd );
  }
  else {
    $str = join( ' ', "yum -q ", @cmd );
  }

  return $str;
}

1;
