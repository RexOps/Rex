#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Commands::Virtualization;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Virtualization;

@EXPORT = qw(vm);

sub vm {
  my ( $action, $vmname, @opt ) = @_;

  my $vm_obj = Rex::Virtualization->create();
  return $vm_obj->execute( $action, $vmname, @opt );
}

=head1 NAME

Rex::Commands::Virtualization - Virtualization module

=head1 DESCRIPTION

With this module you can manage your virtualization.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 SYNOPSIS

 use Rex::Commands::Virtualization;
 
 set virtualization => "LibVirt";
 set virtualization => "VBox";
 
 use Data::Dumper;
 
 print Dumper vm list => "all";
 print Dumper vm list => "running";
 
 vm destroy => "vm01";
 
 vm delete => "vm01";
 
 vm start => "vm01";
 
 vm shutdown => "vm01";
 
 vm reboot => "vm01";
 
 vm option => "vm01",
       max_memory => 1024*1024,
       memory    => 512*1024;
 
 print Dumper vm info => "vm01";
 
 # creating a vm on a kvm host
 vm create => "vm01",
    storage    => [
      {
        file  => "/mnt/data/libvirt/images/vm01.img",
        dev   => "vda",
      }
    ];
 
 print Dumper vm hypervisor => "capabilities";

=head1 EXPORTED FUNCTIONS

=head2 vm($action => $name, %option)

This module only exports the I<vm> function. You can manage everything with this function.

=head1 EXAMPLES

=head2 Creating a Virtual Machine

Create a (VirtualBox) VM named "vm01" with 512 MB ram and 1 cpu. One harddrive, 10 GB in size being a file on disk.
With a cdrom as an iso image and a natted network. The bootorder is set to "dvd".

 vm create => "vm01",
    storage    => [
      {
        file  => "/mnt/data/vbox/vm01.img",
        size  => "10G",
      },
      {
        file => "/mnt/iso/debian6.iso",
      }
    ],
    memory => 512,
    type => "Linux26",
    cpus => 1,
    boot => "dvd";


Create a (KVM) VM named "vm01" with 512 MB ram and 1 cpu. One harddrive, 10 GB in size being a file on disk.
With a cdrom as an iso image and a bridged network on the bridge virbr0. The Bootorder is set to "cdrom".

 vm create => "vm01",
    boot => "cdrom",
    storage    => [
      {
        size  => "10G",
        file  => "/mnt/data/libvirt/images/vm01.img",
      },
 
      {
        file    => "/mnt/data/iso/debian-6.0.2.1-amd64-netinst.iso",
      },
    ];

This is the same as above, but with all options in use.

 vm create => "vm01",
    memory  => 512*1024,
    cpus    => 1,
    arch    => "x86_64",
    boot    => "cdrom",
    clock   => "utc",
    emulator => "/usr/bin/qemu-system-x86_64",
    on_poweroff => "destroy",
    on_reboot  => "restart",
    on_crash   => "restart",
    storage    => [
      {  type  => "file",
        size  => "10G",
        device => "disk",
        driver_type => "qcow2",      # supports all formats qemu-img supports.
        file  => "/mnt/data/libvirt/images/vm01.img",
        dev   => "vda",
        bus   => "virtio",
        address => {
          type    => "pci",
          domain  => "0x0000",
          bus    => "0x00",
          slot    => "0x05",
          function => "0x0",
        },
      },
      {  type    => "file",
        device  => "cdrom",
        file    => "/mnt/data/iso/debian-6.0.2.1-amd64-netinst.iso",
        dev    => "hdc",
        bus    => "ide",
        readonly => 1,
        address  => {
          type     => "drive",
          controller => 0,
          bus      => 1,
          unit     => 0,
        },
      },
    ],
    network => [
      {  type   => "bridge",
        bridge  => "virbr0",
        model  => "virtio",
        address => {
          type    => "pci",
          domain  => "0x0000",
          bus    => "0x00",
          slot    => "0x03",
          function => "0x0",
        },
      },
    ],
    serial_devices => [
      {
        type => 'tcp',
        host => '127.0.0.1',
        port => 12345,
      },
    ];

Create a (Xen/HVM) VM named "vm01" with 512 MB ram and 1 cpu. One harddrive, cloned from an existing one.

 vm create => "vm01",
    type  => "hvm",
    storage    => [
      {
        file    => "/mnt/data/libvirt/images/vm01.img",
        template => "/mnt/data/libvirt/images/svn01.img",
      },
    ];

This is the same as above, but with all options in use.

 vm create => "vm01",
    memory => 512*1024,
    cpus  => 1,
    boot  => "hd",
    clock  => "utc",
    on_poweroff => "destroy",
    on_reboot  => "restart",
    on_crash   => "restart",
    storage    => [
      {  type  => "file",
        size  => "10G",
        device => "disk",
        file  => "/mnt/data/libvirt/images/vm01.img",
        dev   => "hda",
        bus   => "ide",
        template => "/mnt/data/libvirt/images/svn01.img",
      },
      {  type    => "file",
        device  => "cdrom",
        dev    => "hdc",
        bus    => "ide",
        readonly => 1,
      },
    ],
    network => [
      {  type   => "bridge",
        bridge  => "virbr0",
      },
    ],
    type => "hvm";

Create a (Xen/PVM) VM named "vm01" with 512 MB ram and 1 cpu. With one root partition (10GB in size) and one swap parition (1GB in size).

 vm create => "vm01",
    type  => "pvm",
    storage    => [
      {
        file   => "/mnt/data/libvirt/images/domains/vm01/disk.img",
        dev    => "xvda2",
        is_root => 1,
      },
      {
        file  => "/mnt/data/libvirt/images/domains/vm01/swap.img",
        dev   => "xvda1",
      },
    ];

This is the same as above, but with all options in use.

 vm create => "vm01",
    type  => "pvm",
    memory => 512*1024,
    cpus  => 1,
    clock  => "utc",
    on_poweroff => "destroy",
    on_reboot  => "restart",
    on_crash   => "restart",
    os       => {
      type  => "linux",
      kernel => "/boot/vmlinuz-2.6.32-5-xen-amd64",
      initrd => "/boot/initrd.img-2.6.32-5-xen-amd64",
      cmdline => "root=/dev/xvda2 ro",
    },
    storage    => [
      {  type  => "file",
        size  => "10G",
        device => "disk",
        file  => "/mnt/data/libvirt/images/domains/vm01/disk.img",
        dev   => "xvda2",
        bus   => "xen",
        aio   => 1, # if you want to use aio
      },
      {  type  => "file",
        size  => "4G",
        device => "disk",
        file  => "/mnt/data/libvirt/images/domains/vm01/swap.img",
        dev   => "xvda1",
        bus   => "xen",
        aio   => 1, # if you want to use aio
      },
    ],
    network => [
      {  type   => "bridge",
        bridge  => "virbr0",
      },
    ];

=head2 Start/Stop/Destroy

Start a stopped vm

 vm start => "name";

Stop a running vm (send shutdown signal)

 vm shutdown => "name";

Hard Stop a running vm

 vm destroy => "name";


=head2 Delete

 vm delete => "name";

=head2 Modifying a VM

Currently you can only modify the memory.

 vm option => "name",
      max_memory => 1024*1024, # in bytes
      memory    => 512*1024;

=head2 Request information of a vm

 vm info => "name";

=head2 Request info from the underlying hypervisor

 vm hypervisor => "capabilities";

=cut

1;
