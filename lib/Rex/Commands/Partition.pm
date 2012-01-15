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

@EXPORT = qw(clearpart partition);

=item clearpart($drive)

Clear partitions on $drive.

 clearpart "sda";

=cut
sub clearpart {
}

=item partition($mountpoint, %option)

Create a partition with mountpoint $mountpoint.

 partition "/",
    fstype  => "ext3",
    size    => 15000,
    ondisk  => "sda",
    primary => 1,
    grow    => 1;
    
 partition "swap",
    fstype => "swap",
    size   => 8000;


=cut
sub partition {
}

=back

=cut

1;
