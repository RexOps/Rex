#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 8;
use Test::Warnings;

use Rex::Interface::Fs;

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

is( $fs->stat("some_file_that_does_not_exist"),
  undef, "stat should return undef for non-existent files" );
