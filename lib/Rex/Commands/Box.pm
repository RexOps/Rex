#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
=head1 NAME

Rex::Commands::Box - Functions / Class to manage Virtual Machines

=head1 DESCRIPTION

This is a Module to manage Virtual Machines or Cloud Instances in a simple way. Currently it supports only VirtualBox.

=head1 SYNOPSIS

 task mytask => sub {
    
    box {
       my ($box) = @_;
       $box->name("vmname");
       $box->url("http://box.rexify.org/box/base-image.box");
          
       $box->network(1 => {
         type => "nat",
       });
           
       $box->network(1 => {
         type => "bridged",
         bridge => "eth0",
       });
          
       $box->forward_port(ssh => [2222, 22]);
          
       $box->share_folder(myhome => "/home/myuser");
          
       $box->auth(
         user => "root",
         password => "box",
       );
         
       $box->setup(qw/task_to_customize_box/);
       
    };
    
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Box;

use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;

use LWP::UserAgent;
use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

$|++;

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
#@EXPORT = qw(box $box);
@EXPORT = qw(box);

=item new(name => $vmname)

Constructor if used in OO mode.

 my $box = Rex::Commands::Box->new(name => "vmname");

=cut

sub new {
   my $class = shift;
   my $self = { @_ };
   bless($self, ref($class) || $class);

   return $self;
}

sub box(&) {
   my $code = shift;

   #### too much black magic...
   #my ($caller_box) = do {
   #   my $pkg = caller();
   #   no strict 'refs';
   #   \*{ $pkg . "::box" };
   #};

   my $self = {};
   bless($self, __PACKAGE__);

   #local( *$caller_box );
   #*$caller_box = \$self;

   $code->($self);

   #*$caller_box = \{}; # undef $box

   $self->_import;
}

=item name($vmname)

Sets the name of the virtual machine.

=cut
sub name {
   my ($self, $name) = @_;
   $self->{name} = $name;
}

=item setup(@tasks)

Sets the tasks that should be executed as soon as the VM is available throu SSH.

=cut
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

   # get vm infos
   $self->{info} = vm guestinfo => $self->{name};

   if(exists $self->{__tasks}) {
      # provision machine, if tasks exists
      $self->provision;
   }
}

=item stop()

Stops the VM.

=cut
sub stop {
   my ($self) = @_;
   vm shutdown => $self->{name};
}

=item start()

Starts the VM.

=cut
sub start {
   my ($self) = @_;
   vm start => $self->{name};

}

=item provision([@tasks])

Execute's the given tasks on the VM.

=cut
sub provision {
   my ($self, @tasks) = @_;

   if(! @tasks) {
      @tasks = @{ $self->{__tasks} };
   }

   my $server = $self->{info}->{net}->[0]->{ip};
   if($self->{__forward_port} && $self->{__forward_port}->{ssh} && ! Rex::is_local()) {
      $server = connection->server . ":" . $self->{__forward_port}->{ssh}->[0];
   }
   elsif($self->{__forward_port} && $self->{__forward_port}->{ssh} && Rex::is_local()) {
      $server = "127.0.0.1:" . $self->{__forward_port}->{ssh}->[0];
   }

   for my $task (@tasks) {
      Rex::TaskList->create()->get_task($task)->set_auth(%{ $self->{__auth} });
      Rex::TaskList->create()->get_task($task)->run($server);
   }
}

=item cpus($count)

Set the amount of CPUs for the VM.

=cut
sub cpus {
   my ($self, $cpus) = @_;
   $self->{cpus} = $cpus;
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

=item memory($memory_size)

Sets the memory of a VM in megabyte.

=cut
sub memory {
   my ($self, $mem) = @_;
   $self->{memory} = $mem;
}

=item network(%option)

Configure the network for a VM.

Currently it supports 2 modes. I<nat> and I<bridged>. Currently it supports only one network card.

 $box->network(
    1 => {
       type => "nat",
    },
 }
    
 $box->network(
    1 => {
       type => "bridged",
       bridge => "eth0",
    },
 );

=cut
sub network {
   my ($self, %option) = @_;
   $self->{__network} = \%option;
}

=item url($url)

The URL where to download the Base VM Image. You can use self-made images or prebuild images from http://box.rexify.org/.

=cut
sub url {
   my ($self, $url, $force) = @_;
   $self->{url} = $url;
   $self->{force} = $force;
}

=item auth(%option)

Configure the authentication to the VM.

 $box->auth(
    user => $user,
    password => $password,
    private_key => $private_key,
    public_key => $public_key,
 );

=cut
sub auth {
   my ($self, %auth) = @_;
   $self->{__auth} = \%auth;
}

sub _download {
   my ($self) = @_;

   my $filename = basename($self->{url});
   my $force = $self->{force} || FALSE;

   if(is_file("./tmp/$filename")) {
      Rex::Logger::info("File already downloaded. Please remove the file ./tmp/$filename if you want to download a fresh copy.");
   }
   else {
      $force = TRUE;
   }

   if($force) {
      Rex::Logger::info("Downloading $self->{url} to ./tmp/$filename");
      mkdir "tmp";
      if(Rex::is_local()) {
         my $ua = LWP::UserAgent->new();
         my $final_data = "";
         my $current_size = 0;
         my $current_modulo = 0;
         my $start_time = [gettimeofday()];
         open(my $fh, ">", "./tmp/$filename") or die($!);
         binmode $fh;
         my $resp = $ua->get($self->{url}, ':content_cb' => sub {
            my ($data, $response, $protocol) = @_;

            $current_size += length($data);

            my $content_length = $response->header("content-length");

            print $fh $data;

            my $current_time = [gettimeofday()];
            my $time_diff = tv_interval($start_time, $current_time);

            my $bytes_per_seconds = $current_size / $time_diff;

            my $mbytes_per_seconds = $bytes_per_seconds / 1024 / 1024;

            my $mbytes_current = $current_size / 1024 / 1024;
            my $mbytes_total = $content_length / 1024 / 1024;

            my $left_bytes = $content_length - $current_size;

            my $time_one_byte  = $time_diff / $current_size;
            my $time_all_bytes = $time_one_byte * ($content_length - $current_size);

            if( (($current_size / (1024 * 1024)) % (1024 * 1024)) > $current_modulo ) {
               print ".";
               $current_modulo++;

               if( $current_modulo % 10 == 0) {
                  printf(". %.2f MBytes/s (%.2f MByte / %.2f MByte) %.2f secs left\n", $mbytes_per_seconds, $mbytes_current, $mbytes_total, $time_all_bytes);
               }

            }

         });
         close($fh);

         print " done.\n";

      }
      else {
         run "wget -c -qO ./tmp/$filename $self->{url}";

         if($? != 0) {
            die("Downloading of $self->{url} failed. Please verify if wget is installed and if you have the right permissions to download this box.");
         }
      }
   }
}

=back

=cut

1;
