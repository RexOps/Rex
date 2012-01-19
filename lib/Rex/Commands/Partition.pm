#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
   
=head1 NAME

Rex::Commands::Partition - Partition module

=head1 DESCRIPTION

With this Module you can partition your harddrive.

=head1 SYNOPSIS

 use Rex::Commands::Partition;
     


=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Partition;
   
use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::File;

@EXPORT = qw(clearpart partition);

=item clearpart($drive)

Clear partitions on $drive.

 clearpart "sda";
   
 clearpart "sda",
   initialize => "gpt";

=cut
sub clearpart {
   my ($disk, %option) = @_;

   if($option{initialize}) {
      # will destroy partition table
      run "parted -s /dev/$disk mklabel " . $option{initialize};
      if($? != 0) {
         die("Error setting disklabel from $disk to $option{initialize}");
      }
   }
   else {
      my @partitions = grep { /$disk\d+$/ } split /\n/, cat "/proc/partitions";

      for my $part_line (@partitions) {
         my ($num, $part) = ($part_line =~ m/\d+\s+(\d+)\s+\d+\s(.*)$/);
         Rex::Logger::info("Removing $part");
         run "parted -s /dev/$disk rm $num";
      }
   }
}

=item partition($mountpoint, %option)

Create a partition with mountpoint $mountpoint.

 partition "/",
    fstype  => "ext3",
    size    => 15000,
    ondisk  => "sda",
    type    => "primary";
    
 partition "none",
    type   => "extended",
    ondisk => "sda",
    grow   => 1;
    
 partition "swap",
    fstype => "swap",
    type   => "logical",
    ondisk => "sda",
    size   => 8000;


=cut
sub partition {
   my ($mountpoint, %option) = @_;

   $option{type} ||= "primary"; # primary is default

   # info:
   # disk size, partition start, partition end is in MB

   unless($option{ondisk}) {
      die("You have to specify ,,ondisk''.");
   }

   my $disk = $option{ondisk};

   my ($size_line) = grep { /^Disk \/dev\/$disk:/ } run "parted /dev/$disk print";
   my ($disk_size) = ($size_line =~ m/(\d+)s$/);

   my @output_lines = grep { /^\s+\d+/ } run "parted /dev/$disk print";

   my $last_partition_end = 0;
   my $unit;
   if(@output_lines) {
      ($last_partition_end, $unit) = ($output_lines[-1] =~ m/\s+[\d\.]+[a-z]+\s+[\d\.]+[a-z]+\s+([\d\.]+)(MB|GB)/i);
      if($unit eq "GB") { $last_partition_end = $last_partition_end * 1000; } # * 1000 because of parted
   }

   Rex::Logger::info("Last parition ending at $last_partition_end");
   my $next_partition_start = $last_partition_end;
   my $next_partition_end   = $option{size} + $last_partition_end;

   if($option{grow}) {
      $next_partition_end = "-- -1";
   }

   run "parted -s /dev/$disk mkpart $option{type} $next_partition_start $next_partition_end";

   # get the partition id
   my @partitions = grep { /$disk\d+$/ } split /\n/, cat "/proc/partitions";
   my ($part_num) = ($partitions[-1] =~ m/^\s+\d+\s+(\d+)\s+/);

   if($option{boot}) {
      run "parted /dev/$disk set $part_num bios_grub on";
   }

   if(can_run("mkfs.$option{fstype}")) {
      Rex::Logger::info("Creating filesystem $option{fstype} on /dev/$disk$part_num"); 
      run "mkfs.$option{fstype} /dev/$disk$part_num";
   }
   elsif($option{fstype} eq "swap") {
      Rex::Logger::info("Creating swap space on /dev/$disk$part_num");
      run "mkswap /dev/$disk$part_num";
   }
   else {
      die("Can't format partition with $option{fstype}");
   }
}

=back

=cut

1;
