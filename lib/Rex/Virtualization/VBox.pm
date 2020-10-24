#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Virtualization::VBox - VirtualBox Virtualization Module

=head1 DESCRIPTION

With this module you can manage VirtualBox.

=head1 SYNOPSIS

 use Rex::Commands::Virtualization;
   
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
       memory    => 512;
          
 print Dumper vm info => "vm01";
   
 # creating a vm 
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
  
 vm forward_port => "vm01", add => { http => [8080, 80] };
  
 vm forward_port => "vm01", remove => "http";
  
 print Dumper vm guestinfo => "vm01";
   
 vm share_folder => "vm01", add => { sharename => "/path/to/share" };
   
 vm share_folder => "vm01", remove => "sharename";

For VirtualBox memory declaration is always in megabyte.

=cut

package Rex::Virtualization::VBox;

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
