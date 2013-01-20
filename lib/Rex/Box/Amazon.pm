#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Box::Amazon;

use Data::Dumper;
use Rex::Box::Base;
use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Cloud;

use LWP::UserAgent;
use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

use base qw(Rex::Box::Base);

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

   cloud_service "Amazon";
   cloud_auth $self->{options}->{access_key}, $self->{options}->{private_access_key};
   cloud_region $self->{options}->{region};

   return $self;
}

sub import_vm {
   my ($self) = @_;

   # check if machine already exists

   # Rex::Logger::debug("VM already exists. Don't import anything.");
   my @vms = cloud_instance_list;

   my $vminfo;
   my $vm_exists = 0;
   for my $vm (@vms) {
      if($vm->{name} && $vm->{name} eq $self->{name}) {
         Rex::Logger::debug("VM already exists. Don't import anything.");
         $vm_exists = 1;
         $vminfo = $vm;
      }
   }

   if(! $vm_exists) {
      # if not, create it
      Rex::Logger::info("Creating Amazon instance $self->{name}.");
      $vminfo = cloud_instance create => {
         image_id => $self->{ami},
         name     => $self->{name},
         key      => $self->{options}->{auth_key},
         zone     => $self->{options}->{zone},
         type     => $self->{type} || "m1.large",
         security_group => $self->{security_group} || "default",
      };
   }

   # start if stopped
   if($vminfo->{state} eq "stopped") {
      cloud_instance start => $vminfo->{id};
   }

   $self->{info} = $vminfo;
}

=item ami($ami_id)

Set the AMI ID for the box.

=cut
sub ami {
   my ($self, $ami) = @_;
   $self->{ami} = $ami;
}

=item type($type)

Set the type of the Instance. For example "m1.large".

=cut
sub type {
   my ($self, $type) = @_;
   $self->{type} = $type;
}

=item security_group($sec_group)

Set the Amazon security group for this Instance.

=cut
sub security_group {
   my ($self, $sec_group) = @_;
   $self->{security_group} = $sec_group;
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

   $self->wait_for_ssh($ip, $port);

   for my $task (@tasks) {
      Rex::TaskList->create()->get_task($task)->set_auth(%{ $self->{__auth} });
      Rex::TaskList->create()->get_task($task)->run($server);
   }
}

=item forward_port(%option)

Not available for Amazon Boxes.

=cut
sub forward_port { Rex::Logger::debug("Not available for Amazon Boxes."); }

=item share_folder(%option)

Not available for Amazon Boxes.

=cut
sub share_folder { Rex::Logger::debug("Not available for Amazon Boxes."); }

sub list_boxes {
   my ($self) = @_;
   
   my @vms = cloud_instance_list;

   my @ret = grep { $_->{name} 
                 && $_->{state} ne "terminated" 
                 && $_->{state} ne "shutting-down"
               } @vms; # only vms with names...

   return @ret;
}

sub status {
   my ($self) = @_;

   $self->info;

   if($self->{info}->{state} eq "running") {
      return "running";
   }
   else {
      return "stopped";
   }
}

sub start {
   my ($self) = @_;
   
   $self->info;

   Rex::Logger::info("Starting instance: " . $self->{name});

   cloud_instance start => $self->{info}->{id};

   my $server = $self->ip;

   my ($ip, $port) = split(/:/, $server);
   $port ||= 22;

   $self->wait_for_ssh($ip, $port);
}

sub stop {
   my ($self) = @_;
   
   Rex::Logger::info("Stopping instance: " . $self->{name});

   $self->info;

   cloud_instance stop => $self->{info}->{id};
}

=item info

Returns a hashRef of vm information.

=cut
sub info {
   my ($self) = @_;
   ($self->{info}) = grep { $_->{name} eq $self->{name} } $self->list_boxes;
   return $self->{info};
}

sub ip {
   my ($self) = @_;

   # get instance info
   ($self->{info}) = grep { $_->{name} eq $self->{name} } $self->list_boxes;

   return $self->{info}->{ip};
}

1;
