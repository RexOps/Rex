#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::Box;

use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;

use LWP::UserAgent;
use File::Basename qw(basename);

################################################################################
# Setup Virtualization
################################################################################

set virtualization => "VBox";

################################################################################
# BEGIN of class methods
################################################################################

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(box);

sub new {
   my $class = shift;
   my $self = { @_ };
   bless($self, ref($class) || $class);

   return $self;
}

sub box(&) {
   my $code = shift;

   my $self = {};
   bless($self, __PACKAGE__);

   &$code($self);

   $self->_import;
}

sub name {
   my ($self, $name) = @_;
   $self->{name} = $name;
}

sub setup {
   my ($self, @tasks) = @_;
   $self->{__tasks} = \@tasks;
}

sub _import {
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

      Rex::Logger::info("Importing VM /tmp/$filename");
      vm import => $self->{name}, file => "/tmp/$filename", %{ $self };

      unlink "/tmp/$filename";
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

   # get vm infos
   $self->{info} = vm guestinfo => $self->{name};

   if(exists $self->{__tasks}) {
      # provision machine, if tasks exists
      $self->provision;
   }
}

sub stop {
   my ($self) = @_;
   vm shutdown => $self->{name};
}

sub start {
   my ($self) = @_;
   vm start => $self->{name};

}

sub provision {
   my ($self, @tasks) = @_;

   if(! @tasks) {
      @tasks = @{ $self->{__tasks} };
   }

   my $server = $self->{info}->{net}->[0]->{ip};
   if($self->{__forward_port} && $self->{__forward_port}->{ssh}) {
      $server = connection->server . ":" . $self->{__forward_port}->{ssh}->[0];
   }

   for my $task (@tasks) {
      Rex::TaskList->create()->get_task($task)->set_auth(%{ $self->{__auth} });
      Rex::TaskList->create()->get_task($task)->run($server);
   }
}

sub cpus {
   my ($self, $cpus) = @_;
   $self->{cpus} = $cpus;
}

sub forward_port {
   my ($self, %option) = @_;
   $self->{__forward_port} = \%option;
}

sub share_folder {
   my ($self, %option) = @_;
   $self->{__shared_folder} = \%option;
}

sub memory {
   my ($self, $mem) = @_;
   $self->{memory} = $mem;
}

sub network {
   my ($self, %option) = @_;
   $self->{__network} = \%option;
}

sub url {
   my ($self, $url, $force) = @_;
   $self->{url} = $url;
   $self->{force} = $force;
}

sub auth {
   my ($self, %auth) = @_;
   $self->{__auth} = \%auth;
}

sub _download {
   my ($self) = @_;

   my $filename = basename($self->{url});
   my $force = $self->{force} || FALSE;

   if(is_file("/tmp/$filename")) {
      Rex::Logger::info("File already downloaded. Use --force to overwrite.");
   }
   else {
      $force = TRUE;
   }

   if($force) {
      Rex::Logger::info("Downloading $self->{url} to /tmp/$filename");
      mkdir "tmp";
      run "wget -c -qO /tmp/$filename $self->{url}";
   }
}

1;
