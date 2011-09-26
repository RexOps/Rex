#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::create;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Gather;
use Rex::Commands::Fs;
use Rex::Commands::Run;
use Rex::File::Parser::Data;
use Rex::Template;

use XML::Simple;
use Rex::Virtualization::LibVirt::hypervisor;

use Data::Dumper;

my $QEMU_IMG;
if(can_run("qemu-img")) {
   $QEMU_IMG = "qemu-img";
}
elsif(can_run("qemu-img-xen")) {
   $QEMU_IMG = "qemu-img-xen";
}

# read __DATA__ into an array
my @data = <DATA>;

sub execute {
   my ($class, $name, %opt) = @_;

   my $opts = \%opt;
   $opts->{"name"} = $name;

   unless($opts) {
      die("You have to define the create options!");
   }

   ## detect the hypervisor caps
   my $hypervisor = Rex::Virtualization::LibVirt::hypervisor->execute('capabilities');
   my $virt_type = "unknown";

   if(exists $hypervisor->{"emulator"} && ! exists $opts->{"emulator"}) {
      $opts->{"emulator"} = $hypervisor->{"emulator"};

      if(operating_system_is("Debian") && exists $hypervisor->{"xen"}) {
         # fix for debian, because virsh capabilities don't give the correct
         # emulator.
         $opts->{"emulator"} = "/usr/lib/xen-4.0/bin/qemu-dm";
      }
   }

   if(exists $hypervisor->{"loader"} && ! exists $opts->{"loader"}) {
      $opts->{"loader"} = $hypervisor->{"loader"};
   }

   if(exists $hypervisor->{"kvm"}) {
      $virt_type = "kvm";
   }
   elsif(exists $hypervisor->{"xen"}) {
      $virt_type = "xen-" . $opts->{"type"};
   }
   else {
      die("Hypervisor not supported.");
   }

   my $fp = Rex::File::Parser::Data->new(data => \@data);
   my $create_xml = $fp->read("create-${virt_type}.xml");

   my $template = Rex::Template->new;
   my $parsed_template = $template->parse($create_xml, $opts);
   
   Rex::Logger::debug($parsed_template);

   ## create storage devices
   for (@{$opts->{'storage'}}) {
      if($_->{'size'} && $_->{'type'} eq "file") {
         my $size = $_->{'size'};
         if(!is_file($_->{"file"})) {
            Rex::Logger::debug("creating storage disk: \"$_->{file}\"");            
            run "$QEMU_IMG create -f raw $_->{'file'} $size";
            if($? != 0) {
               die("Error creating storage disk: $_->{'file'}");
            }
         }
         else {
            Rex::Logger::info("$_->{file} already exists. Using this.");
         }
      } elsif($_->{'template'} && $_->{'type'} eq "file") {
          Rex::Logger::info("building domain: \"$opts->{'name'}\" from template: \"$_->{'template'}\"");
          Rex::Logger::info("Please wait ...");
          run "$QEMU_IMG convert -f raw $_->{'template'} -O raw $_->{'file'}";
          if($? != 0) {
             die("Error building domain: \"$opts->{'name'}\" from template: \"$_->{'template'}\"\n
             Template doesn't exist or the qemu-img binary is missing")
          }
      }
   } 

   Rex::Logger::info("creating domain: \"$opts->{'name'}\"");

   $parsed_template =~ s/[\n\r]//gms;

   run "virsh define <(echo '$parsed_template')";
   if($? != 0) {
     die("Error starting vm $opts->{name}");
   }

   return;
}

1;

__DATA__

@create-kvm.xml
<domain type="kvm">
  <name><%= $::name %></name>
  <memory><%= $::memory %></memory>
  <currentMemory><%= $::memory %></currentMemory>
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
      <driver name="qemu" type="raw"/>
      <% if ($disk->{file}) { %>
      <source file="<%= $disk->{file} %>"/>
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
      <% if($netdev->{type} eq "bridge") { %>
      <source bridge="<%= $netdev->{bridge} %>"/>
      <% } %>
      <model type="<%= $netdev->{model} %>"/>
      <address <% for my $key (keys %{$netdev->{address}}) { %> <%= $key %>="<%= $netdev->{address}->{$key} %>" <% } %> />
    </interface>
    <% } %>
    <serial type="pty">
      <target port="0"/>
    </serial>
    <console type="pty">
      <target port="0"/>
    </console>
    <input type="mouse" bus="ps2"/>
    <graphics type="vnc" autoport="yes"/>
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
      <% if($netdev->{type} eq "bridge") { %>
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
      <% if($netdev->{type} eq "bridge") { %>
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


