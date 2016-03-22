#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Box::KVM - Rex/Boxes KVM Module

=head1 DESCRIPTION

This is a Rex/Boxes module to use KVM VMs. You need to have libvirt installed.

=head1 EXAMPLES

To use this module inside your Rexfile you can use the following commands.

 use Rex::Commands::Box;
 set box => "KVM";
 
 task "prepare_box", sub {
    box {
       my ($box) = @_;
 
       $box->name("mybox");
       $box->url("http://box.rexify.org/box/ubuntu-server-12.10-amd64.kvm.qcow2");
 
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

 type: KVM
 vms:
    vmone:
       url: http://box.rexify.org/box/ubuntu-server-12.10-amd64.kvm.qcow2
       setup: setup_task

And then you can use it the following way in your Rexfile.

 use Rex::Commands::Box init_file => "file.yml";
 
 task "prepare_vms", sub {
    boxes "init";
 };

=head1 METHODS

See also the Methods of Rex::Box::Base. This module inherits all methods of it.

=cut

package Rex::Box::KVM;

use strict;
use warnings;
use Data::Dumper;
use Rex::Box::Base;
use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;

# VERSION

BEGIN {
  LWP::UserAgent->use;
}

use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

use base qw(Rex::Box::Base);

set virtualization => "LibVirt";

$|++;

################################################################################
# BEGIN of class methods
################################################################################

=head2 new(name => $vmname)

Constructor if used in OO mode.

 my $box = Rex::Box::KVM->new(name => "vmname");

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
  $self->{memory} = $mem * 1024; # libvirt wants kilobytes
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
    $self->_download;

    my $filename = basename( $self->{url} );

    Rex::Logger::info("Importing VM ./tmp/$filename");

    my @options = (
      import => $self->{name},
      file   => "./tmp/$filename",
      %{$self},
    );

    if (Rex::Config::get_use_rex_kvm_agent) {
      my $tcp_port = int( rand(40000) ) + 10000;

      push @options, 'serial_devices',
        [
        {
          type => 'tcp',
          host => '127.0.0.1',
          port => $tcp_port,
        },
        ];

      Rex::Logger::info(
        "Binding a serial device to TCP port $tcp_port for rex-kvm-agent");
    }

    vm @options;

    #unlink "./tmp/$filename";
  }

  my $vminfo = vm info => $self->{name};

  if ( $vminfo->{State} eq "shut off" ) {
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
  return $self->{info}->{network}->[0]->{ip};
}

1;
