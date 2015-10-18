package Rex::Command::Mkfs;

use warnings;
use strict;

# VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

sub mkfs {
    my (%option) = @_;

    if ( !exists $option{size} || !exists $option{onvg} ) {
        die("Missing parameter size or onvg.");
    }

    if ( exists $option{fstype} ) {
        if ( can_run("mkfs.$option{fstype}") ) {
            Rex::Logger::info(
                "Creating filesystem $option{fstype} on /dev/$lv_path");
            run "mkfs.$option{fstype} /dev/$lv_path";
        }
        else {
            die("Can't format partition with $option{fstype}");
        }
    }
}

sub mkswap {
    if ( $option{fstype} eq "swap" ) {
        Rex::Logger::info("Creating swap space on /dev/$lv_path");
        run "mkswap -f /dev/$lv_path";
    }
}

1;
