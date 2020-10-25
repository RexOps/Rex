#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::VBox::create;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Commands::Gather;
use Rex::Hardware;
use Rex::Commands::Fs;
use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::File::Parser::Data;
use Rex::Template;

use XML::Simple;

use Data::Dumper;

sub execute {
  my ( $class, $name, %opt ) = @_;

  my $opts = \%opt;
  $opts->{name} = $name;
  $opts->{type} ||= "Linux26"; # default to Linux 2.6

  unless ($opts) {
    die("You have to define the create options!");
  }

  _set_defaults($opts);

  i_run "VBoxManage createvm --name \""
    . $name
    . "\" --ostype \""
    . $opts->{type}
    . "\" --register";

  ### add controller
  i_run
    "VBoxManage storagectl \"$name\" --name \"SATA Controller\" --add sata --controller IntelAhci";
  i_run
    "VBoxManage storagectl \"$name\" --name \"IDE Controller\" --add ide --controller PIIX4";

  ### create hds
  my $hdd_ports = {
    "sata" => 0,
    "ide"  => 0,
  };

  for my $hd ( @{ $opts->{storage} } ) {
    if ( $hd->{type} eq "file" ) {
      my $filename = $hd->{file};
      my $size     = $hd->{size};
      my $format   = $hd->{format};
      if ( !$filename ) { die("You have to specify 'file'."); }

      if ( $hd->{device} eq "disk" ) {

        if ( !-f $filename ) {
          i_run
            "VBoxManage createhd --filename \"$filename\" --size $size --format $format 2>&1";
        }

        i_run
          "VBoxManage storageattach \"$name\" --storagectl \"SATA Controller\" --port "
          . $hdd_ports->{sata}
          . " --device 0 --type hdd --medium \"$filename\"";
        $hdd_ports->{sata}++;
      }

      if ( $hd->{device} eq "cdrom" ) {
        i_run
          "VBoxManage storageattach \"$name\" --storagectl \"IDE Controller\" --port "
          . $hdd_ports->{ide}
          . " --device 0 --type dvddrive --medium \"$filename\"";
        $hdd_ports->{sata}++;
      }

    }
  }

  # memory
  i_run "VBoxManage modifyvm \"$name\" --memory " . $opts->{memory};

  # cpus
  i_run "VBoxManage modifyvm \"$name\" --cpus " . $opts->{cpus};

  # boot
  i_run "VBoxManage modifyvm \"$name\" --boot1 " . $opts->{boot};

  return;
}

sub _set_defaults {
  my ($opts) = @_;

  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  if ( !exists $opts->{"storage"} ) {
    die("You have to add at least one storage disk.");
  }

  if ( !exists $opts->{"memory"} ) {
    $opts->{"memory"} = 512;
  }
  else {
    # default is mega byte
    $opts->{memory} = $opts->{memory};
  }

  if ( !exists $opts->{"cpus"} ) {
    $opts->{"cpus"} = 1;
  }

  if ( !exists $opts->{"boot"} ) {
    $opts->{"boot"} = "disk";
  }

  # normalize
  if ( $opts->{boot} eq "hd" ) {
    $opts->{boot} = "disk";
  }

  _set_storage_defaults($opts);

  _set_network_defaults($opts);

}

sub _set_storage_defaults {
  my ($opts) = @_;

  my $store_letter = "a";
  for my $store ( @{ $opts->{"storage"} } ) {

    if ( !exists $store->{"type"} ) {
      $store->{"type"} = "file";
    }

    if ( $store->{type} eq "file" && !exists $store->{format} ) {
      $store->{format} = "VDI";
    }

    if ( !exists $store->{"size"} && $store->{"type"} eq "file" ) {
      $store->{"size"} = "10G";
    }

    if ( $store->{type} eq "file" ) {
      $store->{size} = _calc_size( $store->{size} );
    }

    if ( exists $store->{"file"}
      && $store->{"file"} =~ m/\.iso$/
      && !exists $store->{"device"} )
    {
      $store->{"device"} = "cdrom";
    }

    if ( !exists $store->{"device"} ) {
      $store->{"device"} = "disk";
    }

    if ( $store->{"device"} eq "cdrom" ) {
      $store->{"readonly"} = 1;
    }

  }

}

sub _set_network_defaults {
  my ( $opts, $hyper ) = @_;

  if ( !exists $opts->{"network"} ) {
    $opts->{"network"} = [
      {
        type   => "bridge",
        bridge => "eth0",
      },
    ];
  }

  for my $netdev ( @{ $opts->{"network"} } ) {

    if ( !exists $netdev->{"type"} ) {
      $netdev->{"type"} = "bridge";
    }

    if ( !exists $netdev->{"bridge"} ) {
      $netdev->{"bridge"} = "eth0";
    }

  }
}

sub _calc_size {
  my ($size) = @_;

  my $ret_size = 0;
  if ( $size =~ m/^(\d+)G$/ ) {
    $ret_size = $1 * 1024;
  }

  elsif ( $size =~ m/^(\d+)M$/ ) {
    $ret_size = $1;
  }
}

1;
