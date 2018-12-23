#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Resource::pkg::Provider::redhat - Redhat package management.

=head1 DESCRIPTION

This is the package resource provider for redhat based systems.

=head1 PARAMETER

=over 4

=item ensure

What state the resource should be ensured. 

Valid options:

=over 4

=item present

Ensure that the package is installed.

=item absent

Ensure that the package is not installed.

=back

=back

=cut

package Rex::Resource::pkg::Provider::linux::redhat;

use strict;
use warnings;

# VERSION

use Moose;

use Rex::Resource::Common;
use Rex::Helper::Run;
use Data::Dumper;
use Rex::Pkg::Redhat;

require Rex::Commands::File;

extends qw(Rex::Resource::kernel::Provider::base);
with qw(Rex::Resource::Role::Ensureable);

has pkg_mgmt => (
  is => 'ro',
  isa => 'Rex::Pkg::Base',
  default => sub { Rex::Pkg::Redhat->new },
  writer => '_set_pkg_mgmt',
);

sub test {
  my ($self) = @_;
  
  my $pkg = Rex::Pkg::Redhat->new;

  my $pkg_name = $self->config->{package};

  if(ref $pkg_name ne "ARRAY") {
    $pkg_name = [$pkg_name];
  }

  my $is_installed = 1;

  for my $pkg (@{ $pkg_name }) {
    my $_x = $self->pkg_mgmt->is_installed($self->config->{package});
    if(!$_x) {
      # found something todo
      $is_installed = 0;
    }
  }

  return $is_installed;
}

sub present {
  my ($self) = @_;

  my $pkg_name = $self->config->{package};

  if(ref $pkg_name ne "ARRAY") {
    $pkg_name = [$pkg_name];
  }

  my $exit_code = 0;
  eval {
    $self->pkg_mgmt->bulk_install($pkg_name);
    1;  
  } or do {
    $exit_code = 1;
  };

  return {
    value => "",
    exit_code => $exit_code,
    changed => 1,
    status => ($exit_code == 0 ? state_changed : state_failed),
  };
}

sub absent {
  my ($self) = @_;

  my $pkg_name = $self->config->{package};

  if(ref $pkg_name ne "ARRAY") {
    $pkg_name = [$pkg_name];
  }

  my $exit_code = 0;
  eval {
    for my $pkg (@{ $pkg_name }) {
      $self->pkg_mgmt->remove($pkg);
    }
    1;  
  } or do {
    $exit_code = 1;
  };

  return {
    value => "",
    exit_code => $exit_code,
    changed => 1,
    status => ($exit_code == 0 ? state_changed : state_failed),
  };
}

1;
