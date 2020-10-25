#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Box::Amazon - Rex/Boxes Amazon Module

=head1 DESCRIPTION

This is a Rex/Boxes module to use Amazon EC2.

=head1 EXAMPLES

To use this module inside your Rexfile you can use the following commands.

 use Rex::Commands::Box;
 set box => "Amazon", {
   access_key => "your-access-key",
   private_access_key => "your-private-access-key",
   region => "ec2.eu-west-1.amazonaws.com",
   zone => "eu-west-1a",
   authkey => "default",
 };
  
 task "prepare_box", sub {
   box {
     my ($box) = @_;
       
     $box->name("mybox");
     $box->ami("ami-c1aaabb5");
     $box->type("m1.large"); 
        
     $box->security_group("default");
        
     $box->auth(
       user => "root",
       password => "box",
     );
        
     $box->setup("setup_task");
   };
 };

If you want to use a YAML file you can use the following template.

 type: Amazon
 amazon:
   access_key: your-access-key
   private_access_key: your-private-access-key
   region: ec2.eu-west-1.amazonaws.com
   zone: eu-west-1a
   auth_key: default
 vms:
   vmone:
     ami: ami-c1aaabb5
     type: m1.large
     security_group: default
     setup: setup_task

And then you can use it the following way in your Rexfile.

 use Rex::Commands::Box init_file => "file.yml";
   
 task "prepare_vms", sub {
   boxes "init";
 };


=head1 METHODS

See also the Methods of Rex::Box::Base. This module inherits all methods of it.

=cut

package Rex::Box::Amazon;

use 5.010001;
use strict;
use warnings;
use Data::Dumper;
use Rex::Box::Base;
use Rex::Commands -no => [qw/auth/];
use Rex::Commands::Fs;
use Rex::Commands::Cloud;

our $VERSION = '9999.99.99_99'; # VERSION

BEGIN {
  LWP::UserAgent->use;
}

use Time::HiRes qw(tv_interval gettimeofday);
use File::Basename qw(basename);

use base qw(Rex::Box::Base);

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

  cloud_service "Amazon";
  cloud_auth $self->{options}->{access_key},
    $self->{options}->{private_access_key};
  cloud_region $self->{options}->{region};

  return $self;
}

sub import_vm {
  my ($self) = @_;

  # check if machine already exists

  # Rex::Logger::debug("VM already exists. Don't import anything.");
  #my @vms = cloud_instance_list;
  my @vms = $self->list_boxes;

  my $vminfo;
  my $vm_exists = 0;
  for my $vm (@vms) {
    if ( $vm->{name} && $vm->{name} eq $self->{name} ) {
      Rex::Logger::debug("VM already exists. Don't import anything.");
      $vm_exists = 1;
      $vminfo    = $vm;
    }
  }

  if ( !$vm_exists ) {

    # if not, create it
    Rex::Logger::info("Creating Amazon instance $self->{name}.");
    $vminfo = cloud_instance create => {
      image_id       => $self->{ami},
      name           => $self->{name},
      key            => $self->{options}->{auth_key},
      zone           => $self->{options}->{zone},
      type           => $self->{type}           || "m1.large",
      security_group => $self->{security_group} || "default",
      options        => $self->options,
    };
  }

  # start if stopped
  if ( $vminfo->{state} eq "stopped" ) {
    cloud_instance start => $vminfo->{id};
  }

  $self->{info} = $vminfo;
}

=head2 ami($ami_id)

Set the AMI ID for the box.

=cut

sub ami {
  my ( $self, $ami ) = @_;
  $self->{ami} = $ami;
}

=head2 type($type)

Set the type of the Instance. For example "m1.large".

=cut

sub type {
  my ( $self, $type ) = @_;
  $self->{type} = $type;
}

=head2 security_group($sec_group)

Set the Amazon security group for this Instance.

=cut

sub security_group {
  my ( $self, $sec_group ) = @_;
  $self->{security_group} = $sec_group;
}

=head2 forward_port(%option)

Not available for Amazon Boxes.

=cut

sub forward_port { Rex::Logger::debug("Not available for Amazon Boxes."); }

=head2 share_folder(%option)

Not available for Amazon Boxes.

=cut

sub share_folder { Rex::Logger::debug("Not available for Amazon Boxes."); }

sub list_boxes {
  my ($self) = @_;

  my @vms = cloud_instance_list;
  my @ret = grep {
         $_->{name}
      && $_->{state} ne "terminated"
      && $_->{state} ne "shutting-down"
  } @vms; # only vms with names...

  return @ret;
}

sub status {
  my ($self) = @_;

  $self->info;

  if ( $self->{info}->{state} eq "running" ) {
    return "running";
  }
  else {
    return "stopped";
  }
}

sub start {
  my ($self) = @_;

  $self->info;

  Rex::Logger::info( "Starting instance: " . $self->{name} );

  cloud_instance start => $self->{info}->{id};
}

sub stop {
  my ($self) = @_;

  Rex::Logger::info( "Stopping instance: " . $self->{name} );

  $self->info;

  cloud_instance stop => $self->{info}->{id};
}

sub destroy {
  my ($self) = @_;

  Rex::Logger::info( "Destroying instance: " . $self->{name} );

  $self->info;

  cloud_instance terminate => $self->{info}->{id};
}

=head2 info

Returns a hashRef of vm information.

=cut

sub info {
  my ($self) = @_;
  ( $self->{info} ) = grep { $_->{name} eq $self->{name} } $self->list_boxes;
  return $self->{info};
}

sub ip {
  my ($self) = @_;

  # get instance info
  ( $self->{info} ) = grep { $_->{name} eq $self->{name} } $self->list_boxes;

  return $self->{info}->{ip};
}

1;
