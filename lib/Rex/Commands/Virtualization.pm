#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Virtualization;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Config;

@EXPORT = qw(vm);

sub vm {
   my ($action, $vmname, %opt) = @_;

   my $type = Rex::Config->get("virtualization");

   Rex::Logger::debug("Using $type for virtualization");

   my $mod = "Rex::Virtualization::${type}::${action}";
   eval "use $mod;";

   if($@) {
      Rex::Logger::info("No module/action $type/$action available.");
      die("No module/action $type/$action available.");
   }

   return $mod->execute($vmname, %opt);
}

=head1 NAME

Rex::Commands::Virtualization - Virtualization module

=head1 DESCRIPTION

With this module you can manage your virtualization.

=head1 SYNOPSIS

 use Rex::Commands::Virtualization;
    
 set virtualization => "LibVirt";
    
 print Dumper vm list => "all";
 print Dumper vm list => "running";
    
 vm destroy => "vm01";
    
 vm delete => "vm01"; 
     
 vm start => "vm01";
    
 vm shutdown => "vm01";
    
 vm reboot => "vm01";
    
 vm option => "vm01",
          max_memory => 1024*1024,
          memory     => 512*1024;
              
 print Dumper vm info => "vm01";
    
 vm create => "vm01",
          memory  => 512*1024,
          vcpu    => 2,
          storage => [ 
                        { disk  => "file:/pool/vm01.img", dev => "hda", size => "10G" },
                        { cdrom => "file:/iso/debian-6.0.2.1-amd64-netinst.iso", dev => "hdc" },
                     ],
          network => [
                        { bridge => "virbr0", },
                     ],
          boot    => "network",  # default is boot from first harddrive
          vmtype  => "hvm"; # default is pvm
          
 print Dumper vm hypervisor => "capabilities";

=head1 EXPORTED FUNCTIONS

=over 4

=item vm($action => $name, %option)

This module exports only the I<vm> function. You can manage everything with this function.

=back

=head2 Creating a Virtual Machine

Create a VM named "vm01" with 512 MB ram and 2 cpus. One harddrive, 10 GB in size beeing a file on disk.
With a cdrom as an iso image and a bridged network on the bridge virbr0. The Bootorder is set to "network".

 vm create => "vm01",
          memory  => 512*1024,
          vcpu    => 2,
          storage => [ 
                        { disk  => "file:/pool/vm01.img", dev => "hda", size => "10G" },
                        { cdrom => "file:/iso/debian-6.0.2.1-amd64-netinst.iso", dev => "hdc" },
                     ],
          network => [
                        { bridge => "virbr0", },
                     ],
          boot    => "network";

The same, but with a template to clone the vm from. And a second harddrive. But bootet not from network.

 vm create => "vm01",
          memory  => 512*1024,
          vcpu    => 2,
          storage => [ 
                        { disk  => "file:/pool/vm01.img", dev => "hda", template => "/templates/webserver.img" },
                        { disk  => "file:/pool/vm01-2.img", dev => "hdb", size => "10G" },
                        { cdrom => "file:/iso/debian-6.0.2.1-amd64-netinst.iso", dev => "hdc" },
                     ],
          network => [
                        { bridge => "virbr0", },
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
         memory     => 512*1024;

=head2 Request information of a vm

 vm info => "name";

=head2 Request info from the underlying hypervisor

 vm hypervisor => "capabilities";

=cut


1;
