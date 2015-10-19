package Rex::Command::Mkfs;

use warnings;
use strict;

# VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(mkfs mkswap);

use Rex::Commands::Run;

sub mkfs {
    my ($lvname, %option) = @_;

    unless ( ( defined $option{ondisk} ) xor( defined $option{onvg} ) ) {
        die('You have to specify exactly one of ondisk or onvg options.');
    }

    unless ( $lvname =~ m/^[a-z0-9\-\._]+$/i ) {
        die("Error in lvname. Allowed characters a-z, 0-9 and _-. .");
    }

    if ( exists $option{fstype} ) {
        if ( can_run("mkfs.$option{fstype}") ) {
            if ( defined $option{onvg} ) {
                Rex::Logger::info(
                    "Creating filesystem $option{fstype} on /dev/$lv_path");
                run "mkfs.$option{fstype} /dev/$lv_path";
            }
            elsif ( defined $option{ondisk} ) {
                Rex::Logger::info(
                    "Creating filesystem $option{fstype} on /dev/$disk$part_num"
                );

                my $add_opts = "";

                if ( exists $option{label} || exists $option{lable} ) {
                    my $label = $option{label} || $option{lable};
                    $add_opts .= " -L $label ";
                }

                run "mkfs.$option{fstype} $add_opts /dev/$disk$part_num";
            }
        }
    }
    else {
        die("Can't format partition with $option{fstype}");
    }
}

sub mkswap {
    if ( $option{fstype} eq "swap" ) {
        Rex::Logger::info("Creating swap space on /dev/$lv_path");
        run "mkswap -f /dev/$lv_path";
    }
}

1;
