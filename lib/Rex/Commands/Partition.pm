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
use Rex::Commands::Mkfs;
use Rex::Commands qw(TRUE FALSE);

@EXPORT = qw(clearpart partition);

=head2 clearpart($drive)

Clear partitions on drive `sda`:

 clearpart "sda";

Create a new GPT disk label (partition table) on drive `sda`:
 
 clearpart "sda",
  initialize => "gpt";

If GPT initialization is requested, the `bios_boot` option (default: TRUE) can also be set to TRUE or FALSE to control creation of a BIOS boot partition:

 clearpart "sda",
  initialize => "gpt",
  bios_boot => FALSE;

=cut

sub clearpart {
  my ( $disk, %option ) = @_;

  $option{bios_boot} = defined $option{bios_boot} ? $option{bios_boot} : TRUE;

  if ( $option{initialize} ) {

    # will destroy partition table
    run "parted -s /dev/$disk mklabel " . $option{initialize};
    if ( $? != 0 ) {
      die("Error setting disklabel from $disk to $option{initialize}");
    }

    if ( $option{initialize} eq "gpt" && $option{bios_boot} ) {
      Rex::Logger::info("Creating BIOS boot partition");
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

=head2 partition($mountpoint, %option)

Create a partition with the specified parameters:

=over 4

=item ondisk

The disk to be partitioned. Mandatory.

=item size

Desired size of the partition in MB. It is mandatory to pass either a C<size> or a C<grow> parameter (but not both).

=item grow

If C<TRUE>, then the partition will take up all the available space on the disk. It is mandatory to pass either a C<grow> or a C<size> parameter (but not both).

=item type

Partition type to be passed to C<parted>'s C<mkpart> command. Optional, defaults to C<primary>.

=boot

Sets boot flag on the partition if C<TRUE>. Optional, no boot flag is set by default.

=item fstype

Create a filesystem after creating the partition. Optional, no filesystem is created by default.

=item label

Label to be used with the filesystem. Optional, defaults to no label.

=mount

If C<TRUE>, try to mount the partition after creating it. Optional, no mount is attempted by default.

=mount_persistent

If C<TRUE>, try to mount the partition after creating it, and also register it in C</etc/fstab>. Optional, no mount or C</etc/fstab> manipulation is attempted by default.

=vg

Creates an LVM PV, then creates the specifed LVM VG (or extends it, if the VG already exists). Needs C<ondisk>.

=back

Examples:

 partition "/",
   fstype => "ext3",
   size   => 15000,
   ondisk => "sda",
   type   => "primary";
 
 partition "none",
   type   => "extended",
   ondisk => "sda",
   grow   => 1,
   mount  => TRUE,
 
 partition "swap",
   fstype => "swap",
   type   => "logical",
   ondisk => "sda",
   size   => 8000;

 partition "/",
   fstype => "ext3",
   size   => 10000,
   ondisk => "sda",
   vg     => "vg0";

=cut

sub partition {
  my ( $mountpoint, %option ) = @_;

  $option{type} ||= "primary"; # primary is default

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

  mkfs "$disk$part_num", fstype => $option{fstype}, label => $option{label};

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

1;
