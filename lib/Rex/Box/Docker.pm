#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Box::Docker - Rex/Boxes Docker Module

=head1 DESCRIPTION

This is a Rex/Boxes module to use Docker Images. You need to have dockerd installed.

=head1 EXAMPLES

To use this module inside your Rexfile you can use the following commands.

 use Rex::Commands::Box;
 set box => "Docker";
 
 task "prepare_box", sub {
    box {
       my ($box) = @_;
 
       $box->name("mybox");
       $box->url("http://box.rexify.org/box/ubuntu-server-12.10-amd64.tar.gz");
       $box->url("debian:latest");
 
       $box->network(1 => {
          name => "default",
       });
 
       $box->auth(
          user => "root",
          password => "box",
       );
 
       $box->setup("setup_task");
    };
 };

If you want to use a YAML file you can use the following template.

 type: Docker
 vms:
    vmone:
       url: debian:latest
       setup: setup_task

And then you can use it the following way in your Rexfile.

 use Rex::Commands::Box init_file => "file.yml";
 
 task "prepare_vms", sub {
    boxes "init";
 };

=head1 METHODS

See also the Methods of Rex::Box::Base. This module inherits all methods of it.

=cut

package Rex::Box::Docker;

use 5.010001;
use strict;
use warnings;
use Data::Dumper;
use Rex::Box::Base;
use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;
use Rex::Virtualization::Docker::create;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  LWP::UserAgent->use;
}

use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

use base qw(Rex::Box::Base);

set virtualization => "Docker";

$|++;

################################################################################
# BEGIN of class methods
################################################################################

=head2 new(name => $vmname)

Constructor if used in OO mode.

 my $box = Rex::Box::Docker->new(name => "vmname");

=cut

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, ref($class) || $class );

  return $self;
}

=head2 memory($memory_size)

Sets the memory of a VM in megabyte.

=cut

sub memory {
  my ( $self, $mem ) = @_;
  Rex::Logger::debug("Memory option not supported.");
}

sub import_vm {
  my ($self) = @_;

  # check if machine already exists
  my $vms = vm list => "all";

  my $vm_exists = 0;

  for my $vm ( @{$vms} ) {
    if ( $vm->{name} eq $self->{name} ) {
      Rex::Logger::debug("VM already exists. Don't import anything.");
      $vm_exists = 1;
    }
  }

  if ( !$vm_exists ) {

    # if not, create it
    my ($filename);
    if ( $self->{url} =~ m/^(http|https):/ ) {
      $self->_download;
      $filename = "./tmp/" . basename( $self->{url} );
      Rex::Logger::info("Importing VM ./tmp/$filename");
      my @options = (
        import => $self->{name},
        file   => $filename,
        %{$self},
      );
      vm @options;
    }
    else {
      vm import => $self->{name}, file => $self->{url}, %{$self};
    }
  }

  my $vminfo = vm info => $self->{name};

  unless ( $vminfo->{State}->{Running} ) {
    $self->start;
  }

  $self->{info} = vm guestinfo => $self->{name};
}

sub list_boxes {
  my ($self) = @_;

  my $vms = vm list => "all";

  return @{$vms};
}

=head2 info

Returns a hashRef of vm information.

=cut

sub info {
  my ($self) = @_;
  $self->ip;
  return $self->{info};
}

=head2 ip

This method return the ip of a vm on which the ssh daemon is listening.

=cut

sub ip {
  my ($self) = @_;
  $self->{info} = vm guestinfo => $self->{name};

  if ( $self->{info}->{redirects}
    && $self->{info}->{redirects}->{tcp}
    && $self->{info}->{redirects}->{tcp}->{22} )
  {
    return (
      $self->{info}->{redirects}->{tcp}->{22}->[0]->{ip} eq "0.0.0.0"
      ? "127.0.0.1"
      : $self->{info}->{redirects}->{tcp}->{22}->[0]->{ip}
      )
      . ":"
      . $self->{info}->{redirects}->{tcp}->{22}->[0]->{port};
  }
  else {
    return $self->{info}->{network}->[0]->{ip};
  }
}

sub create {
  my ($self) = @_;
  my @options = (
    forward_port => [
          $self->{__forward_port}->{ssh}->[0] . ":"
        . $self->{__forward_port}->{ssh}->[1]
    ],
    image => $self->{url},
  );

  Rex::Virtualization::Docker::create->execute( $self->{name}, @options );
}

1;
