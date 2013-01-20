#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Box::VBox;

use Data::Dumper;
use Rex::Box::Base;
use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;

use LWP::UserAgent;
use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

use base qw(Rex::Box::Base);

set virtualization => "VBox";

$|++;

################################################################################
# BEGIN of class methods
################################################################################

=item new(name => $vmname)

Constructor if used in OO mode.

 my $box = Rex::Box::VBox->new(name => "vmname");

=cut

sub new {
   my $class = shift;
   my $proto = ref($class) || $class;
   my $self = $proto->SUPER::new(@_);

   bless($self, ref($class) || $class);

   return $self;
}

sub import_vm {
   my ($self) = @_;

   # check if machine already exists
   my $vms = vm list => "all";

   my $vm_exists = 0;
   for my $vm (@{ $vms }) {
      if($vm->{name} eq $self->{name}) {
         Rex::Logger::debug("VM already exists. Don't import anything.");
         $vm_exists = 1;
      }
   }

   if(! $vm_exists) {
      # if not, create it
      $self->_download;

      my $filename = basename($self->{url});

      Rex::Logger::info("Importing VM ./tmp/$filename");
      vm import => $self->{name}, file => "./tmp/$filename", %{ $self };

      #unlink "./tmp/$filename";
   }

   my $vminfo = vm info => $self->{name};

   # check if networksettings should be set
   if(exists $self->{__network} && $vminfo->{VMState} ne "running") {
      my $option = $self->{__network};
      for my $nic_no (keys %{ $option }) {

         if($option->{$nic_no}->{type}) {
            Rex::Logger::debug("Setting network type (dev: $nic_no) to: " . $option->{$nic_no}->{type});
            vm option => $self->{name},
                  "nic$nic_no" => $option->{$nic_no}->{type};

            if($option->{$nic_no}->{type} eq "bridged") {
               Rex::Logger::debug("Setting network bridge (dev: $nic_no) to: " . ($option->{$nic_no}->{bridge} || "eth0"));
               vm option => $self->{name},
                  "bridgeadapter$nic_no" => ($option->{$nic_no}->{bridge} || "eth0");
            }
         }

         if($option->{$nic_no}->{driver}) {
            Rex::Logger::debug("Setting network driver (dev: $nic_no) to: " . $option->{$nic_no}->{driver});
            vm option => $self->{name},
                  "nictype$nic_no" => $option->{$nic_no}->{driver};
         }

      }
   }
   if(exists $self->{__forward_port} && $vminfo->{VMState} ne "running") {
      # remove all forwards
      vm forward_port => $self->{name}, delete => -all;

      # add forwards
      vm forward_port => $self->{name}, add => $self->{__forward_port};
   }

   # shared folder
   if(exists $self->{__shared_folder} && $vminfo->{VMState} ne "running") {
      vm share_folder => $self->{name}, add => $self->{__shared_folder};
   }

   if($vminfo->{VMState} ne "running") {
      $self->start;
   }

   $self->{info} = vm guestinfo => $self->{name};
}



=item provision_vm([@tasks])

Execute's the given tasks on the VM.

=cut
sub provision_vm {
   my ($self, @tasks) = @_;

   if(! @tasks) {
      @tasks = @{ $self->{__tasks} };
   }

   my $server = $self->ip;

   my ($ip, $port) = split(/:/, $server);
   $port ||= 22;

   print "Waiting for SSH to come up on $ip:$port.";
   while( ! is_port_open ($ip, $port) ) {
      print ".";
      sleep 1;
   }

   my $i=5;
   while($i != 0) {
      sleep 1;
      print ".";
      $i--;
   }

   print "\n";

   for my $task (@tasks) {
      Rex::TaskList->create()->get_task($task)->set_auth(%{ $self->{__auth} });
      Rex::TaskList->create()->get_task($task)->run($server);
   }
}

=item forward_port(%option)

Set ports to be forwarded to the VM. This only work with VirtualBox in NAT network mode.

 $box->forward_port(
    name => [$from_host_port, $to_vm_port],
    name2 => [$from_host_port_2, $to_vm_port_2],
    ...
 );

=cut
sub forward_port {
   my ($self, %option) = @_;
   $self->{__forward_port} = \%option;
}

=item share_folder(%option)

Creates a shared folder inside the VM with the content from a folder from the Host machine. This only works with VirtualBox.

 $box->share_folder(
    name => "/path/on/host",
    name2 => "/path_2/on/host",
 );

=cut
sub share_folder {
   my ($self, %option) = @_;
   $self->{__shared_folder} = \%option;
}

sub list_boxes {
   my ($self) = @_;
   
   my $vms = vm list => "all";

   return @{ $vms };
}

=item info

Returns a hashRef of vm information.

=cut
sub info {
   my ($self) = @_;
   $self->{info} = vm guestinfo => $self->{name};
   return $self->{info};
}

sub ip {
   my ($self) = @_;

   $self->{info} = vm guestinfo => $self->{name};

   my $server = $self->{info}->{net}->[0]->{ip};
   if($self->{__forward_port} && $self->{__forward_port}->{ssh} && ! Rex::is_local()) {
      $server = connection->server . ":" . $self->{__forward_port}->{ssh}->[0];
   }
   elsif($self->{__forward_port} && $self->{__forward_port}->{ssh} && Rex::is_local()) {
      $server = "127.0.0.1:" . $self->{__forward_port}->{ssh}->[0];
   }

   return $server;
}

1;
