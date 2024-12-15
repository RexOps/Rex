# Slackware
#
# (c) Giuseppe Di Terlizzi <giuseppe.diterlizzi@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Slackware;

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
    install            => 'slackpkg -batch=on -default_answer=y install %s',
    install_version    => 'slackpkg -batch=on -default_answer=y install %s',
    update_system      => 'slackpkg -batch=on -default_answer=y upgrade-all',
    dist_update_system => 'slackpkg -batch=on -default_answer=y upgrade-all',
    remove             => 'slackpkg -batch=on -default_answer=y remove %s',
    update_package_db  => 'slackpkg -batch=on -default_answer=y update',
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
  my ($self) = @_;

  my @ret;

  for my $line ( i_run("ls -d /var/log/packages/* | cut -d '/' -f5-") ) {

    my $name;
    my $version;
    my $build;
    my $tag;
    my $arch;

    # Stantard Slackware Linux package naming:
    #
    # name-1.0-arch-1     (Official:    name + version + arch + build)
    # name-1.0-arch-1tag  (Third-Party: name + version + arch + build + tag)

    my @parts = split /-/, $line;

    $build   = pop @parts;
    $arch    = pop @parts;
    $version = pop @parts;
    $name    = join '-', @parts;

    ( $build, $tag ) = ( $build =~ /^(\d+)(.*)/ );

    push(
      @ret,
      {
        name    => $name,
        version => $version,
        arch    => $arch,
        build   => $build,
        tag     => $tag
      }
    );
  }

  return @ret;
}

1;
