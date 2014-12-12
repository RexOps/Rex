#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Partition - Partition module

=head1 DESCRIPTION

With this Module you can partition your harddrive.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.


=head1 SYNOPSIS

 use Rex::Commands::Partition;



=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Partition;

use strict;
use warnings;

# VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

use Data::Dumper;
use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands::LVM;
use Rex::Commands::Fs;

@EXPORT = qw(clearpart partition);

=item clearpart($drive)

Clear partitions on $drive.

 clearpart "sda";
 
 clearpart "sda",
  initialize => "gpt";

=cut

sub clearpart {
  my ( $disk, %option ) = @_;

  if ( $option{initialize} ) {

    # will destroy partition table
    run "parted -s /dev/$disk mklabel " . $option{initialize};
    if ( $? != 0 ) {
      die("Error setting disklabel from $disk to $option{initialize}");
    }

    if ( $option{initialize} eq "gpt" ) {
      Rex::Logger::info("Creating bios boot partition");
      partition(
        "none",
        fstype => "non-fs",
        ondisk => $disk,
        size   => "1"
      );

      run "parted /dev/$disk set 1 bios_grub on";

    }
  }
  else {
    my @partitions = grep { /$disk\d+$/ } split /\n/, cat "/proc/partitions";

    for my $part_line (@partitions) {
      my ( $num, $part ) = ( $part_line =~ m/\d+\s+(\d+)\s+\d+\s(.*)$/ );
      Rex::Logger::info("Removing $part");
      run "parted -s /dev/$disk rm $num";
    }
  }
}

=item partition($mountpoint, %option)

Create a partition with mountpoint $mountpoint.

 partition "/",
   fstype  => "ext3",
   size   => 15000,
   ondisk  => "sda",
   type   => "primary";
 
 partition "none",
   type  => "extended",
   ondisk => "sda",
   grow  => 1,
   mount  => TRUE,
 
 partition "swap",
   fstype => "swap",
   type  => "logical",
   ondisk => "sda",
   size  => 8000;
 
 partition "none",
   lvm   => 1,
   type  => "primary",
   size  => 15000,
   ondisk => "vda";
 
 partition "/",
   fstype => "ext3",
   size  => 10000,
   onvg  => "vg0";


=cut

sub partition {
  my ( $mountpoint, %option ) = @_;

  $option{type} ||= "primary";    # primary is default

  # info:
  # disk size, partition start, partition end is in MB

  unless ( ( defined $option{grow} ) xor( defined $option{size} ) ) {
    die('You have to specify exactly one of grow or size options.');
  }

  unless ( $option{ondisk} ) {
    die("You have to specify ,,ondisk''.");
  }

  my $disk = $option{ondisk};

  my @output_lines = grep { /^\s+\d+/ } run "parted /dev/$disk unit kB print";

  my $last_partition_end = 1;
  my $unit;
  if (@output_lines) {
    ($last_partition_end) = $output_lines[-1] =~ m/
        ^\s*[\d]       # partition number
        \s+[\d\.]+kB   # partition start
        \s+([\d\.]+)kB # partition end
      /ix;

    # convert kB to MB
    # / 1000 because of parted, + 1 to round up
    $last_partition_end =
      sprintf( "%i", ( ( $last_partition_end / 1000 ) + 1 ) );
  }

  Rex::Logger::info("Last partition ends at $last_partition_end");
  my $next_partition_start = $last_partition_end;
  my $next_partition_end =
    $option{grow} ? "-- -1" : $last_partition_end + $option{size};

  run
    "parted -s /dev/$disk mkpart $option{type} $next_partition_start $next_partition_end";

  if ( $? != 0 ) {
    die("Error creating partition.");
  }

  run "partprobe";

  # get the partition id
  my @partitions = grep { /$disk\d+$/ } split /\n/, cat "/proc/partitions";
  my ($part_num) = ( $partitions[-1] =~ m/$disk(\d+)/ );

  if ( !$part_num ) {
    die("Error getting partition number.");
  }

  if ( $option{boot} ) {
    run "parted /dev/$disk set $part_num boot on";
  }

  if ( $option{vg} ) {
    run "parted /dev/$disk set $part_num lvm on";
    pvcreate "/dev/$disk$part_num";
    my @vgs = vgs();
    if ( grep { $_->{volume_group} eq $option{vg} } @vgs ) {

      # vg exists, so extend it
      vgextend $option{vg}, "/dev/$disk$part_num";
    }
    else {
      # vg doesnt exist, create a new one
      vgcreate $option{vg} => "/dev/$disk$part_num";
    }
  }

  my $found_part = 0;
  while ( $found_part == 0 ) {
    Rex::Logger::debug("Waiting for /dev/$disk$part_num to appear...");

    run "ls -l /dev/$disk$part_num";
    if ( $? == 0 ) { $found_part = 1; last; }

    sleep 1;
  }

  if ( !exists $option{fstype}
    || $option{fstype} eq "non-fs"
    || $option{fstype} eq "none"
    || $option{fstype} eq "" )
  {
    # nix
  }
  elsif ( can_run("mkfs.$option{fstype}") ) {
    Rex::Logger::info(
      "Creating filesystem $option{fstype} on /dev/$disk$part_num");

    my $add_opts = "";

    if ( exists $option{label} || exists $option{lable} ) {
      my $label = $option{label} || $option{lable};
      $add_opts .= " -L $label ";
    }

    run "mkfs.$option{fstype} $add_opts /dev/$disk$part_num";
  }
  elsif ( $option{fstype} eq "swap" ) {
    Rex::Logger::info("Creating swap space on /dev/$disk$part_num");

    my $add_opts = "";

    if ( exists $option{label} || exists $option{lable} ) {
      my $label = $option{label} || $option{lable};
      $add_opts .= " -L $label ";
    }

    run "mkswap $add_opts /dev/$disk$part_num";
  }
  else {
    die("Can't format partition with $option{fstype}");
  }

  if ( exists $option{mount} && $option{mount} ) {
    mount "/dev/$disk$part_num", $mountpoint, fs => $option{fstype};
  }

  if ( exists $option{mount_persistent} && $option{mount_persistent} ) {
    mount "/dev/$disk$part_num", $mountpoint,
      fs         => $option{fstype},
      label      => $option{label} || "",
      persistent => 1;
  }

  return "$disk$part_num";
}

=back

=cut

1;
