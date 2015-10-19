=head1 NAME

Rex::Commands::Mkfs - Create filesystems

=head1 DESCRIPTION

With this module you can create filesystems on existing partitions and logical volumes.

=head1 SYNOPSIS

 use Rex::Commands::Mkfs;

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Mkfs;

use warnings;
use strict;

# VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(mkfs mkswap);

use Rex::Commands::Run;
use Carp;

=head2 mkfs($devname, %option)

Create a filesystem on device $devname.

 mkfs "sda1",
   fstype => "ext3",
   label  => "mydisk";

=cut

sub mkfs {
    my ( $devname, %option ) = @_;

    if ( exists $option{fstype} ) {
        if ( can_run("mkfs.$option{fstype}") ) {
            Rex::Logger::info(
                "Creating filesystem $option{fstype} on /dev/$devname");

            my $add_opts = "";

            if ( exists $option{label} || exists $option{lable} ) {
                my $label = $option{label} || $option{lable};
                $add_opts .= " -L $label ";
            }

            run "mkfs.$option{fstype} $add_opts /dev/$devname";
        }
    }
    else {
        die("Can't format partition with $option{fstype}");
    }

    return;
}

=head2 mkswap($devname, %option)

Create swap space on device $devname.

 mkfs "sda2",
   fstype => "swap";

=cut

sub mkswap {
    my ( $devname, %option ) = @_;

    if ( $option{fstype} eq "swap" ) {
        Rex::Logger::info("Creating swap space on /dev/$lv_path");
        run "mkswap -f /dev/$devname";
    }
	else {
		croak "Can't create swap partition");
	}

    return;
}

1;
