use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

use_ok 'Rex::Interface::Fs';

my $fs = Rex::Interface::Fs->create("Local");

ok( $fs, "created fs interface object" );

my @files = $fs->ls(".");
ok( grep { /^Makefile\.PL$/ } @files, "found Makefile.PL" );

ok( $fs->is_file("Makefile.PL"), "Makefile.PL is a file" );
ok( $fs->is_dir("."),            ". is a directory" );

$fs->mkdir("foo");
ok( $fs->is_dir("foo"), "mkdir" );

$fs->rmdir("foo");
ok( !$fs->is_dir("foo"), "rmdir" );

