#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::create;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Commands::Fs;
use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::File::Parser::Data;
use Rex::Template;
use Rex::Helper::Path;

use XML::Simple;
use Rex::Virtualization::LibVirt::hypervisor;

use Data::Dumper;

my $QEMU_IMG;
if ( can_run("qemu-img") ) {
  $QEMU_IMG = "qemu-img";
}
elsif ( can_run("qemu-img-xen") ) {
  $QEMU_IMG = "qemu-img-xen";
}

# read __DATA__ into an array
my @data = <DATA>;

sub execute {
  my ( $class, $name, %opt ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  my $opts = \%opt;
  $opts->{"name"} = $name;

  unless ($opts) {
    die("You have to define the create options!");
  }

  ## detect the hypervisor caps
  my $hypervisor =
    Rex::Virtualization::LibVirt::hypervisor->execute('capabilities');
  my $virt_type = "unknown";

  _set_defaults( $opts, $hypervisor );

  if ( exists $hypervisor->{"kvm"} ) {
    $virt_type = "kvm";
  }
  elsif ( exists $hypervisor->{"xen"} ) {
    $virt_type = "xen-" . $opts->{"type"};
  }
  else {
    die("Hypervisor not supported.");
  }

  my $fp         = Rex::File::Parser::Data->new( data => \@data );
  my $create_xml = $fp->read("create-${virt_type}.xml");

  my $template        = Rex::Template->new;
  my $parsed_template = $template->parse( $create_xml, $opts );

  Rex::Logger::debug($parsed_template);

  ## create storage devices
  for ( @{ $opts->{'storage'} } ) {

    if ( !exists $_->{"template"} && $_->{"size"} && $_->{"type"} eq "file" ) {
      my $size = $_->{'size'};
      if ( !is_file( $_->{"file"} ) ) {
        Rex::Logger::debug("creating storage disk: \"$_->{file}\"");
        i_run "$QEMU_IMG create -f $_->{driver_type} '$_->{file}' $size",
          fail_ok => 1;
        if ( $? != 0 ) {
          die("Error creating storage disk: $_->{'file'}");
        }
      }
      else {
        Rex::Logger::info("$_->{file} already exists. Using this.");
      }
    }
    elsif ( $_->{'template'} && $_->{'type'} eq "file" ) {
      Rex::Logger::info(
        "building domain: \"$opts->{'name'}\" from template: \"$_->{'template'}\""
      );
      Rex::Logger::info("Please wait ...");
      i_run
        "$QEMU_IMG convert -f raw '$_->{template}' -O '$_->{driver_type}' '$_->{file}'",
        fail_ok => 1;
      if ( $? != 0 ) {
        die(
          "Error building domain: \"$opts->{'name'}\" from template: \"$_->{'template'}\"\n
             Template doesn't exist or the qemu-img binary is missing"
        );
      }
    }
    else {
      Rex::Logger::info("$_->{file} already exists. Using this.");
    }
  }

  Rex::Logger::info("Creating domain: \"$opts->{'name'}\"");

  $parsed_template =~ s/[\n\r]//gms;

  my $file_name = get_tmp_file;

  file "$file_name", content => $parsed_template;

  i_run "virsh -c $uri define '$file_name'", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error defining vm $opts->{name}");
  }
  unlink($file_name);

  return;
}

sub _set_defaults {
  my ( $opts, $hyper ) = @_;

  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  if ( !exists $opts->{"storage"} ) {
    die("You have to add at least one storage disk.");
  }

  if ( !exists $opts->{"type"} ) {

    if ( exists $opts->{"os"}
      && exists $opts->{"os"}->{"kernel"}
      && !exists $hyper->{"kvm"} )
    {
      $opts->{"type"} = "pvm";
    }
    else {
      $opts->{"type"} = "hvm";
    }

  }

  if ( !$opts->{"memory"} ) {
    $opts->{"memory"} = 512 * 1024;
  }

  if ( !$opts->{"cpus"} ) {
    $opts->{"cpus"} = 1;
  }

  if ( !exists $opts->{"clock"} ) {
    $opts->{"clock"} = "utc";
  }

  if ( !exists $opts->{"arch"} ) {
    if ( exists $hyper->{"x86_64"} ) {
      $opts->{"arch"} = "x86_64";
    }
    else {
      $opts->{"arch"} = "i686";
    }
  }

  if ( !exists $opts->{"boot"} ) {
    $opts->{"boot"} = "hd";
  }

  if ( !exists $opts->{"emulator"} ) {
    $opts->{"emulator"} = $hyper->{"emulator"};

    if ( operating_system_is("Debian") && exists $hyper->{"xen"} ) {

      # fix for debian, because virsh capabilities don't give the correct
      # emulator.
      $opts->{"emulator"} = "/usr/lib/xen-4.0/bin/qemu-dm";
    }

  }

  if ( exists $hyper->{"loader"} && !exists $opts->{"loader"} ) {
    $opts->{"loader"} = $hyper->{"loader"};
  }

  if ( !exists $opts->{"on_poweroff"} ) {
    $opts->{"on_poweroff"} = "destroy";
  }

  if ( !exists $opts->{"on_reboot"} ) {
    $opts->{"on_reboot"} = "restart";
  }

  if ( !exists $opts->{"on_crash"} ) {
    $opts->{"on_crash"} = "restart";
  }

  if ( exists $hyper->{"xen"} && $opts->{"type"} eq "pvm" ) {

    if ( !exists $opts->{"os"}->{"type"} ) {
      $opts->{"os"}->{"type"} = "linux";
    }

    if ( !exists $opts->{"os"}->{"kernel"} ) {
      my %hw = Rex::Hardware->get(qw/ Kernel /);

      if ( is_redhat() ) {
        $opts->{"os"}->{"kernel"} =
          "/boot/vmlinuz-" . $hw{"Kernel"}->{"kernelrelease"};
      }
      else {
        $opts->{"os"}->{"kernel"} =
          "/boot/vmlinuz-" . $hw{"Kernel"}->{"kernelrelease"};
      }
    }

    if ( !exists $opts->{"os"}->{"initrd"} ) {
      my %hw = Rex::Hardware->get(qw/ Kernel /);

      if ( is_redhat() ) {
        $opts->{"os"}->{"initrd"} =
          "/boot/initrd-" . $hw{"Kernel"}->{"kernelrelease"} . ".img";
      }
      else {
        $opts->{"os"}->{"initrd"} =
          "/boot/initrd.img-" . $hw{"Kernel"}->{"kernelrelease"};
      }
    }

    if ( !exists $opts->{"os"}->{"cmdline"} ) {
      my @root_store = grep { $_->{"is_root"} && $_->{"is_root"} == 1 }
        @{ $opts->{"storage"} };
      $opts->{"os"}->{"cmdline"} =
        "root=/dev/" . $root_store[0]->{"dev"} . " ro";
    }

  }

  _set_storage_defaults( $opts, $hyper );

  _set_network_defaults( $opts, $hyper );

}

sub _set_storage_defaults {
  my ( $opts, $hyper ) = @_;

  my $store_letter = "a";
  for my $store ( @{ $opts->{"storage"} } ) {

    if ( !exists $store->{"type"} ) {
      $store->{"type"} = "file";
    }

    if ( !exists $store->{"driver_type"} ) {
      $store->{"driver_type"} = "raw";
    }

    if ( !exists $store->{"size"} && $store->{"type"} eq "file" ) {

      if ( $store->{"file"} =~ m/swap/ ) {
        $store->{"size"} = "1G";
      }
      else {
        $store->{"size"} = "10G";
      }

    }

    if ( exists $store->{"file"}
      && $store->{"file"} =~ m/\.iso$/
      && !exists $store->{"device"} )
    {
      $store->{"device"} = "cdrom";
    }

    if ( !exists $store->{"device"} ) {
      $store->{"device"} = "disk";
    }

    if ( !exists $store->{"dev"} && $store->{"device"} eq "cdrom" ) {
      $store->{"dev"} = "hdc";
    }

    if ( !exists $store->{"dev"} ) {

      if ( exists $hyper->{"kvm"} ) {
        $store->{"dev"} = "vd${store_letter}";
      }
      else {
        $store->{"dev"} = "hd${store_letter}";
      }

    }

    if ( !exists $store->{"bus"} ) {

      if ( exists $hyper->{"kvm"} && $store->{"device"} eq "disk" ) {
        $store->{"bus"} = "virtio";
      }
      else {
        $store->{"bus"} = "ide";
      }

    }

    if ( exists $hyper->{"kvm"} ) {

      if ( $store->{"bus"} eq "virtio" && !exists $store->{"address"} ) {
        $store->{"address"} = {
          type     => "pci",
          domain   => "0x0000",
          bus      => "0x00",
          slot     => "0x05",
          function => "0x0",
        };
      }
      elsif ( $store->{"bus"} eq "ide" && !exists $store->{"address"} ) {
        $store->{"address"} = {
          type       => "drive",
          controller => 0,
          bus        => 1,
          unit       => 0,
        };
      }

    }

    if ( $store->{"device"} eq "cdrom" ) {
      $store->{"readonly"} = 1;
    }

    if ( is_redhat() ) {

      if ( !exists $store->{"aio"} ) {
        $store->{"aio"} = 1;
      }

    }

    $store_letter++;

  }

}

sub _set_network_defaults {
  my ( $opts, $hyper ) = @_;

  if ( !exists $opts->{"network"} ) {
    $opts->{"network"} = [
      {
        type   => "bridge",
        bridge => "virbr0",
      },
    ];
  }

  my $slot = 10;

  for my $netdev ( @{ $opts->{"network"} } ) {

    if ( !exists $netdev->{"type"} ) {

      $netdev->{"type"} = "bridge";

    }

    if ( !exists $netdev->{"bridge"} ) {

      $netdev->{"bridge"} = "virbr0";

    }

    if ( exists $hyper->{"kvm"} ) {

      if ( !exists $netdev->{"model"} ) {

        $netdev->{"model"} = "virtio";

      }

      if ( !exists $netdev->{"address"} ) {

        $netdev->{"address"} = {
          type     => "pci",
          domain   => "0x0000",
          bus      => "0x00",
          slot     => "0x" . sprintf( '%02i', $slot ),
          function => "0x0",
        };

        $slot++;

      }

    }

  }
}

1;

__DATA__

@create-kvm.xml
<domain type="kvm">
  <name><%= $::name %></name>
  <memory><%= $::memory %></memory>
  <currentMemory><%= $::memory %></currentMemory>
  <% if(exists $::cpu->{mode}) { %>
   <cpu mode="<%= $::cpu->{mode} %>" />
  <% } %>
  <vcpu><%= $::cpus %></vcpu>
  <os>
   <type arch="<%= $::arch %>">hvm</type>
   <boot dev="<%= $::boot %>"/>
  </os>
  <features>
   <acpi/>
   <apic/>
   <pae/>
  </features>
  <clock offset="<%= $::clock %>"/>
  <on_poweroff><%= $::on_poweroff %></on_poweroff>
  <on_reboot><%= $::on_reboot %></on_reboot>
  <on_crash><%= $::on_crash %></on_crash>
  <devices>
   <emulator><%= $::emulator %></emulator>

   <% for my $disk (@{$::storage}) { %>
   <disk type="<%= $disk->{type} %>" device="<%= $disk->{device} %>">
    <driver name="qemu" type="<%= $disk->{driver_type} %>"/>
    <% if ($disk->{type} eq "file") { %>
    <source file="<%= $disk->{file} %>"/>
    <% } elsif ($disk->{file} eq "block") { %>
    <source dev="<%= $disk->{file} %>"/>
    <% } %>
    <% if(exists $disk->{readonly}) { %>
    <readonly/>
    <% } %>
    <target dev="<%= $disk->{dev} %>" bus="<%= $disk->{bus} %>"/>
    <address <% for my $key (keys %{$disk->{address}}) { %> <%= $key %>="<%= $disk->{address}->{$key} %>" <% } %> />
   </disk>
   <% } %>
   <controller type="ide" index="0">
    <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x1"/>
   </controller>
   <% for my $netdev (@{$::network}) { %>
   <interface type="<%= $netdev->{type} %>">
    <% if(exists $netdev->{mac}) { %>
    <mac address='<%= $netdev->{mac} %>'/>
    <% } %>
    <% if($netdev->{type} =~ m/^bridge/) { %>
    <source bridge="<%= $netdev->{bridge} %>"/>
    <% } elsif($netdev->{type} eq "network") { %>
    <source network="<%= $netdev->{network} %>"/>
    <% } %>
    <model type="<%= $netdev->{model} %>"/>
    <address <% for my $key (keys %{$netdev->{address}}) { %> <%= $key %>="<%= $netdev->{address}->{$key} %>" <% } %> />
   </interface>
   <% } %>
   <serial type="pty">
    <target port="0"/>
   </serial>
   <% my $serial_i = 1; %>
   <% for my $serial (@{ $serial_devices }) { %>
   <% if($serial->{type} eq "tcp") { %>
   <serial type='<%= $serial->{type} %>'>
     <source mode='bind' host='<%= $serial->{host} %>' service='<%= $serial->{port} %>'/>
     <protocol type='raw'/>
     <target port='<%= $serial_i %>'/>
   </serial>
   <% } %>
   <% $serial_i++; %>
   <% } %>
   <console type="pty">
    <target port="0"/>
   </console>
   <input type="mouse" bus="ps2"/>
   <graphics type="vnc" autoport="yes" listen="0.0.0.0"/>
   <video>
    <model type="cirrus" vram="9216" heads="1"/>
    <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0"/>
   </video>
   <memballoon model="virtio">
    <address type="pci" domain="0x0000" bus="0x00" slot="0x06" function="0x0"/>
   </memballoon>
  </devices>
</domain>
@end

@create-xen-hvm.xml
<domain type="xen">
  <name><%= $::name %></name>
  <memory><%= $::memory %></memory>
  <currentMemory><%= $::memory %></currentMemory>
  <vcpu><%= $::cpus %></vcpu>
  <os>
   <type>hvm</type>
   <loader><%= $::loader %></loader>
   <boot dev="<%= $::boot %>"/>
  </os>
  <features>
   <acpi/>
   <apic/>
   <pae/>
  </features>
  <clock offset="<%= $::clock %>">
   <timer name="hpet" present="no"/>
  </clock>
  <on_poweroff><%= $::on_poweroff %></on_poweroff>
  <on_reboot><%= $::on_reboot %></on_reboot>
  <on_crash><%= $::on_crash %></on_crash>
  <devices>
   <emulator><%= $::emulator %></emulator>

   <% for my $disk (@{$::storage}) { %>
   <disk type="<%= $disk->{type} %>" device="<%= $disk->{device} %>">
    <% if(exists $disk->{file}) { %>
    <driver name="file"/>
    <source file="<%= $disk->{file} %>"/>
    <% } %>
    <target dev="<%= $disk->{dev} %>" bus="<%= $disk->{bus} %>"/>
    <% if(exists $disk->{readonly}) { %>
    <readonly/>
    <% } %>
   </disk>
   <% } %>

   <% for my $netdev (@{$::network}) { %>
   <interface type="<%= $netdev->{type} %>">
    <% if(exists $netdev->{mac}) { %>
    <mac address='<%= $netdev->{mac} %>'/>
    <% } %>
    <% if($netdev->{type} =~ m/^bridge/) { %>
    <source bridge="<%= $netdev->{bridge} %>"/>
    <% } %>
   </interface>
   <% } %>
   <graphics type="vnc" autoport="yes"/>
   <serial type="pty">
    <target port="0"/>
   </serial>
   <console type="pty">
    <target port="0"/>
   </console>
  </devices>
</domain>
@end

@create-xen-pvm.xml
<domain type="xen">
  <name><%= $::name %></name>
  <memory><%= $::memory %></memory>
  <currentMemory><%= $::memory %></currentMemory>
  <vcpu><%= $::cpus %></vcpu>
  <% if(defined $::bootloader) { %>
  <bootloader><%= $::bootloader %></bootloader>
  <% } %>
  <os>
   <type><%= $::os->{type} %></type>
   <% if(exists $::os->{kernel}) { %>
   <kernel><%= $::os->{kernel} %></kernel>
   <% } %>
   <% if(exists $::os->{initrd}) { %>
   <initrd><%= $::os->{initrd} %></initrd>
   <% } %>
   <% if(exists $::os->{cmdline}) { %>
   <cmdline><%= $::os->{cmdline} %></cmdline>
   <% } %>
  </os>
  <clock offset="<%= $::clock %>"/>
  <on_poweroff><%= $::on_poweroff %></on_poweroff>
  <on_reboot><%= $::on_reboot %></on_reboot>
  <on_crash><%= $::on_crash %></on_crash>
  <devices>

   <% for my $disk (@{$::storage}) { %>
   <disk type="<%= $disk->{type} %>" device="<%= $disk->{device} %>">
    <% if($disk->{aio}) { %>
    <driver name="tap" type="aio"/>
    <% } else { %>
    <driver name="file"/>
    <% } %>
    <% if(exists $disk->{file}) { %>
    <source file="<%= $disk->{file} %>"/>
    <% } %>
    <target dev="<%= $disk->{dev} %>" bus="<%= $disk->{bus} %>"/>
   </disk>
   <% } %>

   <% for my $netdev (@{$::network}) { %>
   <interface type="<%= $netdev->{type} %>">
    <% if(exists $netdev->{mac}) { %>
    <mac address="<%= $netdev->{mac} %>"/>
    <% } %>
    <% if($netdev->{type} =~ m/^bridge/) { %>
    <source bridge="<%= $netdev->{bridge} %>"/>
    <% } %>
   </interface>
   <% } %>
   <graphics type="vnc" autoport="yes"/>
   <console type="pty">
    <target port="0"/>
   </console>
  </devices>
</domain>

@end
