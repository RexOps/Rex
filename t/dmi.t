use Test::More tests => 29;
use Data::Dumper;

use_ok 'Rex::Inventory::DMIDecode';

my @lines = eval { local (@ARGV) = ("t/dmi.linux.out"); <>; };
my $dmi = Rex::Inventory::DMIDecode->new( lines => \@lines );

ok( ref($dmi) eq "Rex::Inventory::DMIDecode", "dmi object" );

my $bb      = $dmi->get_base_board;
my $bios    = $dmi->get_bios;
my @cpus    = $dmi->get_cpus;
my @mems    = $dmi->get_memory_modules;
my @mema    = $dmi->get_memory_arrays;
my $sysinfo = $dmi->get_system_information;

ok( $bb->get_product_name() eq "Parallels Virtual Platform",
  "get base board product name" );
ok( $bios->get_vendor eq "Parallels Software International Inc.",
  "get bios vendor" );
ok( $bios->get_version =~ /\d\.0\./, "get bios version" );
ok( $bios->get_release_date eq "10/26/2007" );

ok(
  $cpus[0]->get_max_speed eq "2800 MHz"
    || $cpus[0]->get_max_speed eq "30000 MHz"
    || $cpus[0]->get_max_speed eq "2800MHz",
  "cpu get max speed"
);
ok( $mems[0]->get_size eq "512 MB" || $mems[0]->get_size eq "1073741824 bytes",
  "memory size" );

ok(
  $mema[0]->get_maximum_capacity eq "8 GB"
    || $mema[0]->get_maximum_capacity eq "256 GB"
    || $mema[0]->get_maximum_capacity eq "8589934592 bytes",
  "memory array max capacity"
);

ok( $sysinfo->get_manufacturer eq "Parallels Software International Inc.",
  "system information manucafturer" );
ok( $sysinfo->get_product_name eq "Parallels Virtual Platform",
  "system information product name" );

@lines   = undef;
$dmi     = undef;
$bb      = undef;
$bios    = undef;
@cpus    = undef;
@mems    = undef;
@mema    = undef;
$sysinfo = undef;

@lines = eval { local (@ARGV) = ("t/dmi.obsd.out"); <>; };
$dmi = Rex::Inventory::DMIDecode->new( lines => \@lines );

$bb      = $dmi->get_base_board;
$bios    = $dmi->get_bios;
@cpus    = $dmi->get_cpus;
@mems    = $dmi->get_memory_modules;
@mema    = $dmi->get_memory_arrays;
$sysinfo = $dmi->get_system_information;

ok( $bb->get_product_name() eq "Parallels Virtual Platform",
  "get base board product name" );
ok( $bios->get_vendor eq "Parallels Software International Inc.",
  "get bios vendor" );
ok( $bios->get_version =~ /\d\.0\./, "get bios version" );
ok( $bios->get_release_date eq "10/26/2007" );

ok(
  $cpus[0]->get_max_speed eq "2800 MHz"
    || $cpus[0]->get_max_speed eq "30000 MHz"
    || $cpus[0]->get_max_speed eq "2800MHz",
  "cpu get max speed"
);
ok( $mems[0]->get_size eq "512 MB" || $mems[0]->get_size eq "1073741824 bytes",
  "memory size" );

ok(
  $mema[0]->get_maximum_capacity eq "8 GB"
    || $mema[0]->get_maximum_capacity eq "256 GB"
    || $mema[0]->get_maximum_capacity eq "8589934592 bytes",
  "memory array max capacity"
);

ok( $sysinfo->get_manufacturer eq "Parallels Software International Inc.",
  "system information manucafturer" );
ok( $sysinfo->get_product_name eq "Parallels Virtual Platform",
  "system information product name" );

@lines   = undef;
$dmi     = undef;
$bb      = undef;
$bios    = undef;
@cpus    = undef;
@mems    = undef;
@mema    = undef;
$sysinfo = undef;

@lines = eval { local (@ARGV) = ("t/dmi.fbsd.out"); <>; };
$dmi = Rex::Inventory::DMIDecode->new( lines => \@lines );

$bb      = $dmi->get_base_board;
$bios    = $dmi->get_bios;
@cpus    = $dmi->get_cpus;
@mems    = $dmi->get_memory_modules;
@mema    = $dmi->get_memory_arrays;
$sysinfo = $dmi->get_system_information;

ok( $bb->get_product_name() eq "Parallels Virtual Platform",
  "get base board product name" );
ok( $bios->get_vendor eq "Parallels Software International Inc.",
  "get bios vendor" );
ok( $bios->get_version =~ /\d\.0\./, "get bios version" );
ok( $bios->get_release_date eq "10/26/2007" );

ok(
  $cpus[0]->get_max_speed eq "2800 MHz"
    || $cpus[0]->get_max_speed eq "30000 MHz"
    || $cpus[0]->get_max_speed eq "2800MHz",
  "cpu get max speed"
);
ok( $mems[0]->get_size eq "512 MB" || $mems[0]->get_size eq "1073741824 bytes",
  "memory size" );

ok(
  $mema[0]->get_maximum_capacity eq "8 GB"
    || $mema[0]->get_maximum_capacity eq "256 GB"
    || $mema[0]->get_maximum_capacity eq "8589934592 bytes",
  "memory array max capacity"
);

ok( $sysinfo->get_manufacturer eq "Parallels Software International Inc.",
  "system information manucafturer" );
ok( $sysinfo->get_product_name eq "Parallels Virtual Platform",
  "system information product name" );

