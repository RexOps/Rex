#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Box::VBox - Rex/Boxes VirtualBox Module

=head1 DESCRIPTION

This is a Rex/Boxes module to use VirtualBox VMs.

=head1 EXAMPLES

To use this module inside your Rexfile you can use the following commands.

 use Rex::Commands::Box;
 set box => "VBox";
 
 task "prepare_box", sub {
   box {
     my ($box) = @_;
 
     $box->name("mybox");
     $box->url("http://box.rexify.org/box/ubuntu-server-12.10-amd64.ova");
 
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
 
     $box->setup("setup_task");
   };
 };

If you want to use a YAML file you can use the following template.

 type: VBox
 vms:
   vmone:
     url: http://box.rexify.org/box/ubuntu-server-12.10-amd64.ova
     forward_port:
       ssh:
         - 2222
         - 22
     share_folder:
       myhome: /home/myhome
     setup: setup_task

And then you can use it the following way in your Rexfile.

 use Rex::Commands::Box init_file => "file.yml";
 
 task "prepare_vms", sub {
   boxes "init";
 };

=head1 HEADLESS MODE

It is also possible to run VirtualBox in headless mode. This only works on Linux and MacOS. If you want to do this you can use the following option at the top of your I<Rexfile>.

 set box_options => { headless => TRUE };

=head1 METHODS

See also the Methods of Rex::Box::Base. This module inherits all methods of it.

=cut

package Rex::Box::VBox;

use 5.010001;
use strict;
use warnings;
use Data::Dumper;
use Rex::Box::Base;
use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Fs;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  LWP::UserAgent->use;
}

use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

use base qw(Rex::Box::Base);

set virtualization => "VBox";

$|++;

################################################################################
# BEGIN of class methods
################################################################################

=head2 new(name => $vmname)

Constructor if used in OO mode.

 my $box = Rex::Box::VBox->new(name => "vmname");

=cut

sub new {
  my $class = shift;
  my $proto = ref($class) || $class;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, ref($class) || $class );

  if ( exists $self->{options}
    && exists $self->{options}->{headless}
    && $self->{options}->{headless} )
  {
    set virtualization => { type => "VBox", headless => TRUE };
  }

  $self->{get_ip_count} = 0;

  return $self;
}

sub import_vm {
  my ($self) = @_;

  # check if machine already exists
  my $vms = vm list => "all";

  my $vm_exists = 0;
  for my $vm ( @{$vms} ) {
    if ( $vm->{name} eq $self->{name} ) {
      Rex::Logger::debug("VM already exists. Don't import anything.");
      $vm_exists = 1;
    }
  }

  if ( !$vm_exists ) {

    # if not, create it
    $self->_download;

    my $filename = basename( $self->{url} );

    Rex::Logger::info("Importing VM ./tmp/$filename");
    vm import => $self->{name}, file => "./tmp/$filename", %{$self};

    #unlink "./tmp/$filename";
  }

  my $vminfo = vm info => $self->{name};

  # check if networksettings should be set
  if ( exists $self->{__network} && $vminfo->{VMState} ne "running" ) {
    my $option = $self->{__network};
    for my $nic_no ( keys %{$option} ) {

      if ( $option->{$nic_no}->{type} ) {
        Rex::Logger::debug( "Setting network type (dev: $nic_no) to: "
            . $option->{$nic_no}->{type} );
        vm
          option       => $self->{name},
          "nic$nic_no" => $option->{$nic_no}->{type};

        if ( $option->{$nic_no}->{type} eq "bridged" ) {

          $option->{$nic_no}->{bridge} = select_bridge()
            if ( !$option->{$nic_no}->{bridge} );

          Rex::Logger::debug( "Setting network bridge (dev: $nic_no) to: "
              . ( $option->{$nic_no}->{bridge} || "eth0" ) );
          vm
            option                 => $self->{name},
            "bridgeadapter$nic_no" =>
            ( $option->{$nic_no}->{bridge} || "eth0" );
        }
      }

      if ( $option->{$nic_no}->{driver} ) {
        Rex::Logger::debug( "Setting network driver (dev: $nic_no) to: "
            . $option->{$nic_no}->{driver} );
        vm
          option           => $self->{name},
          "nictype$nic_no" => $option->{$nic_no}->{driver};
      }

    }
  }
  if ( exists $self->{__forward_port} && $vminfo->{VMState} ne "running" ) {

    # remove all forwards
    vm forward_port => $self->{name}, delete => -all;

    # add forwards
    vm forward_port => $self->{name}, add => $self->{__forward_port};
  }

  # shared folder
  if ( exists $self->{__shared_folder} && $vminfo->{VMState} ne "running" ) {
    vm share_folder => $self->{name}, add => $self->{__shared_folder};
  }

  if ( $vminfo->{VMState} ne "running" ) {
    $self->start;
  }

  $self->{info} = vm guestinfo => $self->{name};
}

sub select_bridge {
  my $bridges = vm "bridge";

  my $ifname;
  if ( @$bridges == 1 ) {
    Rex::Logger::debug(
      "Only one bridged interface available. Using it by default.");
    $ifname = $bridges->[0]->{name};
  }
  elsif ( @$bridges > 1 ) {
    for ( my $i = 0 ; $i < @$bridges ; $i++ ) {
      my $bridge = $bridges->[$i];
      next if ( $bridge->{status} =~ /^down$/i );
      local $Rex::Logger::format = "%s";
      Rex::Logger::info( $i + 1 . " $bridge->{name}" );
    }

    my $choice;
    do {
      print "What interface should network bridge to? ";
      chomp( $choice = <STDIN> );
      $choice = int($choice);
    } while ( !$choice );

    $ifname = $bridges->[ $choice - 1 ]->{name};
  }

  return $ifname;
}

=head2 share_folder(%option)

Creates a shared folder inside the VM with the content from a folder from the Host machine. This only works with VirtualBox.

 $box->share_folder(
   name => "/path/on/host",
   name2 => "/path_2/on/host",
 );

=cut

sub share_folder {
  my ( $self, %option ) = @_;
  $self->{__shared_folder} = \%option;
}

=head2 info

Returns a hashRef of vm information.

=cut

sub info {
  my ($self) = @_;
  $self->ip;

  my $vm_info = vm info => $self->{name};

  # get forwarded ports
  my @forwarded_ports = grep { m/^Forwarding/ } keys %{$vm_info};

  my %forward_port;
  for my $fwp (@forwarded_ports) {
    my ( $name, $proto, $host_ip, $host_port, $vm_ip, $vm_port ) =
      split( /,/, $vm_info->{$fwp} );
    $forward_port{$name} = [ $host_port, $vm_port ];
  }
  $self->forward_port(%forward_port);

  return $self->{info};
}

=head2 ip

This method return the ip of a vm on which the ssh daemon is listening.

=cut

sub ip {
  my ($self) = @_;

  $self->{info} ||= vm guestinfo => $self->{name};

  if ( scalar keys %{ $self->{info} } == 0 ) { return; }

  my $server = $self->{info}->{net}->[0]->{ip};
  if ( $self->{__forward_port}
    && $self->{__forward_port}->{ssh}
    && !Rex::is_local() )
  {
    $server = connection->server . ":" . $self->{__forward_port}->{ssh}->[0];
  }
  elsif ( $self->{__forward_port}
    && $self->{__forward_port}->{ssh}
    && Rex::is_local() )
  {
    $server = "127.0.0.1:" . $self->{__forward_port}->{ssh}->[0];
  }

  $self->{info}->{ip} = $server;

  if ( !$server ) {
    sleep 1;
    $self->{get_ip_count}++;

    if ( $self->{get_ip_count} >= 30 ) {
      die "Can't get ip of VM.";
    }

    my $ip = $self->ip;
    if ($ip) {
      $self->{get_ip_count} = 0;
      return $ip;
    }
  }

  return $server;
}

1;
