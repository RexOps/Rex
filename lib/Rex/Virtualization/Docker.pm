#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Virtualization::Docker - Docker Virtualization Module

=head1 DESCRIPTION

With this module you can manage Docker.

=head1 SYNOPSIS

 use Rex::Commands::Virtualization;
   
 set virtualization => "Docker";
   
 use Data::Dumper;  
  
 print Dumper vm list => "all";
 print Dumper vm list => "running";
 
 print Dumper vm info => "vm01";
   
 vm destroy => "vm01";
   
 vm delete => "vm01"; 
    
 vm start => "vm01";
   
 vm shutdown => "vm01";
   
 vm reboot => "vm01";
   
 # creating a vm 
 my $id = vm create => "vm01",
    image => "ubuntu",
    command => 'echo hello world',
    memory => 512,
    cpus => 1,
    links => ['mysql:db'],
    forward_port => [8080 => 80],
    share_folder => ["hostdir" => "vmdir"],

=cut

package Rex::Virtualization::Docker;

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
