#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::LibVirt::create;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

use XML::Simple;
use Rex::Virtualization::LibVirt::hypervisor;

use Data::Dumper;


sub _template_xen_pvm {

     return "<domain type='xen'>
     <description></description>
     <bootloader>/usr/bin/pygrub</bootloader>
     <bootloader_args>-q</bootloader_args>
     <clock offset='utc'/>
     <on_poweroff>destroy</on_poweroff>
     <on_reboot>restart</on_reboot>
     <on_crash>destroy</on_crash>
     <devices>
       <graphics type='vnc' port='-1' autoport='yes' keymap='us'/>
     </devices>
   </domain>";

}

sub _template_xen_hvm {

   return "<domain type='xen'>
         <description></description>
         <os>
            <type>hvm</type>
            <loader>default</loader>
         </os>
         <features>
            <acpi/>
            <apic/>
            <pae/>
         </features>
         <clock offset='utc'/>
         <on_poweroff>destroy</on_poweroff>
         <on_reboot>restart</on_reboot>
         <on_crash>restart</on_crash>
         <devices>
            <emulator>default</emulator>
            <input type='mouse' bus='ps2'/>
            <graphics type='vnc' port='-1' autoport='yes' keymap='us'/>
         </devices>
      </domain>";

}

sub _template_kvm {

   return "<domain type='kvm'>
        <os>
          <type>hvm</type>
        </os>
        <features>
          <acpi/>
          <apic/>
          <pae/>
        </features>
        <clock offset='utc'/>
        <on_poweroff>destroy</on_poweroff>
        <on_reboot>restart</on_reboot>
        <on_crash>restart</on_crash>
        <devices>
          <emulator>default</emulator>
          <input type='mouse' bus='ps2'/>
          <graphics type='vnc' port='-1' autoport='yes' keymap='us'/>
        </devices>
      </domain>";

}

sub _template_storage_helper {

   my $storage       = shift;
   my $domain_type   = shift;

   my $tpl;

   ## set defaults
   unless(defined($storage->{'bus'})) {
      $storage->{'bus'} = 'ide';
   }

   if(defined($storage->{'disk'}) && $storage->{'disk'} =~ m:^file\:(.+):) {
      $storage->{'disk'} = $1;
      $tpl               = {'type' => 'file', 'device'=> 'disk'};

      ## default values for xen pvm machines
      if($domain_type eq 'xen-pvm') {
         $tpl->{'driver'}  = {'name' => 'tap', 'type' => 'aio'};
         $tpl->{'target'}  = {'dev' => $storage->{'dev'}, 'bus' => 'xen' };
      } else {
         $tpl->{'target'}  = {'dev' => $storage->{'dev'}, 'bus' => $storage->{'bus'} };
      }

      $tpl->{'source'}  = {'file' => $storage->{'disk'} };

   } elsif (defined($storage->{'cdrom'}) && $storage->{'cdrom'} =~ m:^file\:(.+):) {

      $storage->{'cdrom'} = $1;
      $tpl                = {'type' => 'file', 'device'=> 'cdrom'};
      $tpl->{'target'}    = {'dev' => $storage->{'dev'}, 'bus' => $storage->{'bus'} };
      $tpl->{'source'}    = {'file' => $storage->{'cdrom'} };

   } else { 
      Rex::Logger::info("Wrong Storage definition ...");
   }

   return $tpl;

}

sub _template_storage {

   my $storage_ref = shift;
   my $xml_ref     = shift; 

   for my $storage (@$storage_ref) {
      ## check if pvm
      if(defined($xml_ref->{'domain'}->{'bootloader'})) {
         if($xml_ref->{'domain'}->{'type'} eq 'xen') {
            push(@{$xml_ref->{'domain'}->{'devices'}->{'disk'}},
               _template_storage_helper($storage, $xml_ref->{'domain'}->{'type'}."-pvm"));
         } else {
            Rex::Logger::info("No or wrong Storage definition ...");
         }
      } else {
         if($xml_ref->{'domain'}->{'type'} eq 'xen' || $xml_ref->{'domain'}->{'type'} eq 'kvm') {
            push(@{$xml_ref->{'domain'}->{'devices'}->{'disk'}},
               _template_storage_helper($storage, $xml_ref->{'domain'}->{'type'}));

         } else {
            Rex::Logger::info("No or wrong Storage definition ...");
         }
      }
   }

   return $xml_ref;

}

sub _template_network {

   my $network_ref = shift;
   my $xml_ref     = shift; 

   for (@$network_ref) {
      if($_->{'bridge'}) {
         $xml_ref->{'domain'}->{'devices'}->{'interface'}->{'type'}                 = 'bridge';
         $xml_ref->{'domain'}->{'devices'}->{'interface'}->{'source'}->{'bridge'}   = $_->{'bridge'};
         $xml_ref->{'domain'}->{'devices'}->{'interface'}->{'source'}->{'bridge'}   = $_->{'bridge'};
      } else {
         Rex::Logger::info("No or wrong Network definition ...");
      }
   }

   return $xml_ref;

}


sub prepare_instance_create {

   my $opts  =  shift;
   my $xs = XML::Simple->new();
   my $template;

   ## templates for the different types of hypervisors
   if($opts->{'hypervisor'}->{'xen'}) {
      if(defined($opts->{'vmtype'}) && $opts->{'vmtype'} eq 'pvm') {
         $template = _template_xen_pvm;
      } else {
         $template = _template_xen_hvm;
      }
   } elsif($opts->{'hypervisor'}->{'kvm'}) {
         $template = _template_kvm;
   } else {
      die("Cannot detect hypervisor ....");
   }  

   my $ref = $xs->XMLin($template, KeepRoot => 1, KeyAttr => 1, ForceContent => 1);

   ## some fixes of the xml format
   $ref->{'domain'}->{'devices'}->{'content'}   = "" if defined($ref->{'domain'}->{'devices'});
   $ref->{'domain'}->{'features'}->{'content'}  = "" if defined($ref->{'domain'}->{'features'});
   $ref->{'domain'}->{'os'}->{'content'}        = "" if defined($ref->{'domain'}->{'os'});

   $ref->{'domain'}->{'devices'}->{'emulator'}->{'content'} = $opts->{'hypervisor'}->{'emulator'}
   if defined($ref->{'domain'}->{'devices'}->{'emulator'});

   $ref->{'domain'}->{'os'}->{'loader'}->{'content'} = $opts->{'hypervisor'}->{'loader'}
   if defined($ref->{'domain'}->{'os'}->{'loader'});

   ## templates for the storage
   if(ref($opts->{'storage'}) eq 'ARRAY') {
      $ref = _template_storage($opts->{'storage'},$ref);
   } else {
      die("No or wrong Storage definition ...");
   }

   ## templates for the network
   if(ref($opts->{'network'}) eq 'ARRAY') {
      $ref = _template_network($opts->{'network'},$ref);
   } else {
      die("No or wrong Network definition ...");
   }

   ## set vm properties
   $ref->{'domain'}->{'name'}->{'content'}    = $opts->{'name'};
   $ref->{'domain'}->{'memory'}->{'content'}  = $opts->{'memory'};
   $ref->{'domain'}->{'vcpu'}->{'content'}    = $opts->{'vcpu'} || 1;

   ## set optional parameters
   $ref->{'domain'}->{'os'}->{'boot'}->{'dev'} = $opts->{'boot'} if defined($opts->{'boot'});

   return $xs->XMLout($ref, RootName => undef, NoEscape => 1);

};

sub execute {
   my ($class, $name, %opt) = @_;
   my $opts = \%opt;
   $opts->{"name"} = $name;

   unless($opts) {
      die("You have to define the create options!");
   }

   ## detect the hypervisor caps
   $opts->{'hypervisor'} = Rex::Virtualization::LibVirt::hypervisor->execute('capabilities');

   my $template = prepare_instance_create($opts);

   ## create storage devices
   for (@{$opts->{'storage'}}) {
      if($_->{'size'} && $_->{'disk'}) {
         my $size = $_->{'size'};
         Rex::Logger::debug("creating storage disk: \"$_->{'disk'}\"");            
         run "qemu-img create -f raw $_->{'disk'} $size";
         if($? != 0) {
            die("Error creating storage disk: $_->{'disk'}");
         }
      } elsif($_->{'template'} && $_->{'disk'}) {
          Rex::Logger::info("building domain: \"$opts->{'name'}\" from template: \"$_->{'template'}\"");
          Rex::Logger::info("Please wait ...");
          run "qemu-img convert -f raw $_->{'template'} -O raw $_->{'disk'}";
          if($? != 0) {
             die("Error building domain: \"$opts->{'name'}\" from template: \"$_->{'template'}\"\n
             Template doesn't exist or the qemu-img binary is missing")
          }
      }
   } 

   Rex::Logger::info("creating domain: \"$opts->{'name'}\"");

   run "virsh define <(echo '$template')";
   if($? != 0) {
     die("Error starting vm $opts");
   }

   return;
}

1;
