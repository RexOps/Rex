#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Virtualization::LibVirt - LibVirt Virtualization Module

=head1 DESCRIPTION

With this module you can manage LibVirt.

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

=cut

package Rex::Virtualization::LibVirt;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Virtualization::Base;
use base qw(Rex::Virtualization::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

1;
