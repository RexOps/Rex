use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

use_ok 'Rex::Interface::Fs';

my $fs = Rex::Interface::Fs->create("Local");

ok( $fs, "created fs interface object" );

my @files = $fs->ls(".");
ok( grep { /^ChangeLog$/ } @files, "found ChangeLog" );

is( $fs->is_file("ChangeLog"), 1, "ChangeLog is a file" );
is( $fs->is_dir("."),          1, ". is a directory" );

$fs->mkdir("foo");
is( $fs->is_dir("foo"), 1, "mkdir" );

$fs->rmdir("foo");
is( $fs->is_dir("foo"), undef, "rmdir" );

