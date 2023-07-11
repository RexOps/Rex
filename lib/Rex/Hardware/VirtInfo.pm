package Rex::Hardware::VirtInfo;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex;
use Rex::Helper::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;

use Rex::Inventory::Bios;

require Rex::Hardware;

sub get {

  my $cache          = Rex::get_cache();
  my $cache_key_name = $cache->gen_key_name("hardware.virt_info");

  if ( $cache->valid($cache_key_name) ) {
    return $cache->get($cache_key_name);
  }

  if ( Rex::is_ssh || $^O !~ m/^MSWin/i ) {

    my (
      $product_name, $bios_vendor, $sys_vendor,
      $self_status,  $cpuinfo,     $modules
    ) = ( '', '', '', '', '', '' );

    if ( $^O eq 'linux' ) {
      $product_name =
        i_run "cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null",
        fail_ok => 1;
      $bios_vendor =
        i_run "cat /sys/devices/virtual/dmi/id/bios_vendor 2>/dev/null",
        fail_ok => 1;
      $sys_vendor =
        i_run "cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null",
        fail_ok => 1;
    }
    else {
      my $bios = Rex::Inventory::Bios::get();
      $bios_vendor  = $bios->get_bios()->get_vendor;
      $product_name = $bios->get_system_information()->get_product_name;
      $sys_vendor   = $bios->get_system_information()->get_manufacturer;
    }

    $self_status = i_run "cat /proc/self/status 2>/dev/null", fail_ok => 1;

    if ( $^O eq 'linux' ) {
      $cpuinfo = i_run "cat /proc/cpuinfo 2>/dev/null", fail_ok => 1;
    }
    else {
      $cpuinfo = i_run "dmidecode -t processor 2>/dev/null", fail_ok => 1;
    }

    if ( $^O eq 'linux' ) {
      $modules = i_run "cat /proc/modules 2>/dev/null", fail_ok => 1;
    }
    elsif ( $^O eq 'freebsd' ) {
      $modules = i_run "/sbin/kldstat 2>/dev/null", fail_ok => 1;
    }

    my ( $virtualization_type, $virtualization_role ) = ( '', '' );

    if ( is_dir("/proc/xen") ) {
      $virtualization_type = "xen";
      $virtualization_role = "guest";

      my $string = i_run "cat /proc/xen/capabilities 2>/dev/null", fail_ok => 1;
      if ( $string =~ /control_d/ ) {
        $virtualization_role = "host";
      }
    }

    elsif ( is_dir("/proc/vz") ) {
      $virtualization_type = "openvz";
      $virtualization_role = "guest";

      if ( is_dir("/proc/bc") ) {
        $virtualization_role = "host";
      }
    }

    elsif ( $product_name =~ /KVM|Bochs/ ) {
      $virtualization_type = "kvm";
      $virtualization_role = "guest";
    }

    elsif ( $product_name =~ /VMware Virtual Platform/ ) {
      $virtualization_type = "vmware";
      $virtualization_role = "guest";
    }

    elsif ( $product_name =~ /BHYVE/ ) {
      $virtualization_type = "bhyve";
      $virtualization_role = "guest";
    }

    elsif ( $bios_vendor =~ /Xen/ ) {
      $virtualization_type = "xen";
      $virtualization_role = "guest";
    }

    elsif ( $bios_vendor =~ /innotek GmbH/ ) {
      $virtualization_type = "virtualbox";
      $virtualization_role = "guest";
    }

    elsif ( $bios_vendor =~ /BHYVE/ ) {
      $virtualization_type = "bhyve";
      $virtualization_role = "guest";
    }

    elsif ( $sys_vendor =~ /Microsoft Corporation/ ) {
      $virtualization_type = "VirtualPC";
      $virtualization_role = "guest";
    }

    elsif ( $sys_vendor =~ /Parallels Software International Inc/ ) {
      $virtualization_type = "parallels";
      $virtualization_role = "guest";
    }

    elsif ( $sys_vendor =~ /QEMU/ ) {
      $virtualization_type = "kvm";
      $virtualization_role = "guest";
    }

    elsif ( $sys_vendor =~ /DigitalOcean/ ) {
      $virtualization_type = "kvm";
      $virtualization_role = "guest";
    }

    elsif ( $self_status =~ /VxID: \d+/ ) {
      $virtualization_type = "linux_vserver";
      $virtualization_role = "guest";

      if ( $self_status =~ /VxID: 0/ ) {
        $virtualization_role = "host";
      }
    }

    elsif ( $^O eq 'linux' && $cpuinfo =~ /model name.*QEMU Virtual CPU/ ) {
      $virtualization_type = "kvm";
      $virtualization_role = "guest";
    }

    elsif ( $^O ne 'linux' && $cpuinfo =~ /Manufacturer.*QEMU Virtual CPU/ ) {
      $virtualization_type = "qemu";
      $virtualization_role = "guest";
    }

    elsif ( $^O eq 'linux'
      && $cpuinfo =~ /vendor_id.*User Mode Linux|model name.*UML/ )
    {
      $virtualization_type = "uml";
      $virtualization_role = "guest";
    }

    elsif ( $^O ne 'linux'
      && $cpuinfo =~ /Manufacturer.*User Mode Linux|model name.*UML/ )
    {
      $virtualization_type = "uml";
      $virtualization_role = "guest";
    }

    elsif ( $^O eq 'linux' && $cpuinfo =~ /vendor_id.*PowerVM Lx86/ ) {
      $virtualization_type = "powervm_lx86";
      $virtualization_role = "guest";
    }

    elsif ( $^O ne 'linux' && $cpuinfo =~ /Manufacturer.*PowerVM Lx86/ ) {
      $virtualization_type = "powervm_lx86";
      $virtualization_role = "guest";
    }

    elsif ( $^O eq 'linux' && $cpuinfo =~ /vendor_id.*IBM\/S390/ ) {
      $virtualization_type = "ibm_systemz";
      $virtualization_role = "guest";
    }

    elsif ( $^O ne 'linux' && $cpuinfo =~ /Manufacturer.*IBM\/S390/ ) {
      $virtualization_type = "ibm_systemz";
      $virtualization_role = "guest";
    }

    elsif ( $modules =~ /kvm/ && $^O eq 'linux' ) {
      $virtualization_type = "kvm";
      $virtualization_role = "host";
    }

    elsif ( $modules =~ /vmm/ && $^O eq 'freebsd' ) {
      $virtualization_type = "bhyve";
      $virtualization_role = "host";
    }

    elsif ( $modules =~ /vboxdrv/ ) {
      $virtualization_type = "virtualbox";
      $virtualization_role = "host";
    }

    my $data = {
      virtualization_type => $virtualization_type,
      virtualization_role => $virtualization_role,
    };

    $cache->set( $cache_key_name, $data );

    return $data;

  }
}
