package Rex::Hardware::VirtInfo;

use strict;
use warnings;

use Rex;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;

use Rex::Inventory::Bios;

require Rex::Hardware;

sub get {

   if(my $ret = Rex::Hardware->cache("VirtInfo")) {
      return $ret;
   }

   if(Rex::is_ssh || $^O !~ m/^MSWin/i) {

      my ($product_name,$bios_vendor,$sys_vendor,$self_status,$cpuinfo,$modules) = ('','','','','','');

      $product_name = run "cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null";
      $bios_vendor  = run "cat /sys/devices/virtual/dmi/id/bios_vendor 2>/dev/null";
      $sys_vendor   = run "cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null";

      $self_status  = run "cat /proc/self/status 2>/dev/null";
      $cpuinfo      = run "cat /proc/cpuinfo 2>/dev/null";
      $modules      = run "cat /proc/modules 2>/dev/null";

      my ($virtualization_type, $virtualization_role) = ('','');

      if (is_dir("/proc/xen")) {
         $virtualization_type = "xen";
         $virtualization_role = "guest";

         my $string = run "cat /proc/xen/capabilities 2>/dev/null";
         if ($string =~ /control_d/){
            $virtualization_role = "host";
         }
      }

      elsif (is_dir("/proc/vz")) {
         $virtualization_type = "openvz";
         $virtualization_role = "guest";

         if (is_dir("/proc/bc")) {
            $virtualization_role = "host";
         }
      }

      elsif ($product_name =~ /KVM|Bochs/) {
         $virtualization_type = "kvm";
         $virtualization_role = "guest";
      }

      elsif ($product_name =~ /VMware Virtual Platform/) {
         $virtualization_type = "vmware";
         $virtualization_role = "guest";
      }

      elsif ($bios_vendor =~ /Xen/) {
         $virtualization_type = "xen";
         $virtualization_role = "guest";
      }

      elsif ($bios_vendor =~ /innotek GmbH/) {
         $virtualization_type = "virtualbox";
         $virtualization_role = "guest";
      }

      elsif ($sys_vendor =~ /Microsoft Corporation/) {
         $virtualization_type = "VirtualPC";
         $virtualization_role = "guest";
      }

      elsif ($sys_vendor =~ /Parallels Software International Inc/) {
         $virtualization_type = "parallels";
         $virtualization_role = "guest";
      }

      elsif ($self_status =~ /VxID: \d+/) {
         $virtualization_type = "linux_vserver";
         $virtualization_role = "guest";

        if ($self_status =~ /VxID: 0/) {
           $virtualization_role = "host";
        }
      }

      elsif ($cpuinfo =~ /model name.*QEMU Virtual CPU/) {
         $virtualization_type = "kvm";
         $virtualization_role = "guest";
      }

      elsif ($cpuinfo =~ /vendor_id.*User Mode Linux|model name.*UML/) {
         $virtualization_type = "uml";
         $virtualization_role = "guest";
      }

      elsif ($cpuinfo =~ /vendor_id.*PowerVM Lx86/) {
         $virtualization_type = "powervm_lx86";
         $virtualization_role = "guest";
      }

      elsif ($cpuinfo =~ /vendor_id.*IBM\/S390/) {
         $virtualization_type = "ibm_systemz";
         $virtualization_role = "guest";
      }

      elsif ($modules =~ /kvm/) {
         $virtualization_type = "kvm";
         $virtualization_role = "host";
      }

      elsif ($modules =~ /vboxdrv/) {
         $virtualization_type = "virtualbox";
         $virtualization_role = "host";
      }

      return {
         virtualization_type => $virtualization_type,
         virtualization_role => $virtualization_role,
      };

   }
}
