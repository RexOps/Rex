#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 37;
use Test::Warnings;

use Rex::Commands::Fs;

my @lines = eval { local (@ARGV) = ("t/df.out2"); <>; };

my $df = Rex::Commands::Fs::_parse_df(@lines);

ok( exists $df->{tmpfs}, "found tmpfs" );
is( $df->{tmpfs}->{used_perc},  '0%',       "tmpfs percent usage" );
is( $df->{tmpfs}->{free},       255160,     "tmpfs free" );
is( $df->{tmpfs}->{mounted_on}, "/dev/shm", "tmpfs mounted_on" );
is( $df->{tmpfs}->{used},       0,          "tmpfs used" );
is( $df->{tmpfs}->{size},       255160,     "tmpfs size" );

ok( exists $df->{"/dev/sda1"}, "found /dev/sda1" );
is( $df->{"/dev/sda1"}->{used_perc},  '15%',   "/dev/sda1 percent usage" );
is( $df->{"/dev/sda1"}->{free},       402687,  "/dev/sda1 free" );
is( $df->{"/dev/sda1"}->{mounted_on}, "/boot", "/dev/sda1 mounted_on" );
is( $df->{"/dev/sda1"}->{used},       67557,   "/dev/sda1 used" );
is( $df->{"/dev/sda1"}->{size},       495844,  "/dev/sda1 size" );

ok( exists $df->{"/dev/sda2"}, "found /dev/sda2" );
is( $df->{"/dev/sda2"}->{used_perc},  '10%',    "/dev/sda2 percent usage" );
is( $df->{"/dev/sda2"}->{free},       15489344, "/dev/sda2 free" );
is( $df->{"/dev/sda2"}->{mounted_on}, "/",      "/dev/sda2 mounted_on" );
is( $df->{"/dev/sda2"}->{used},       1693244,  "/dev/sda2 used" );
is( $df->{"/dev/sda2"}->{size},       18102140, "/dev/sda2 size" );

@lines = ();
$df    = {};

@lines = eval { local (@ARGV) = ("t/df.out1"); <>; };

$df = Rex::Commands::Fs::_parse_df(@lines);

ok( exists $df->{tmpfs}, "found tmpfs" );
is( $df->{tmpfs}->{used_perc},  '0%',       "tmpfs percent usage" );
is( $df->{tmpfs}->{free},       255160,     "tmpfs free" );
is( $df->{tmpfs}->{mounted_on}, "/dev/shm", "tmpfs mounted_on" );
is( $df->{tmpfs}->{used},       0,          "tmpfs used" );
is( $df->{tmpfs}->{size},       255160,     "tmpfs size" );

ok( exists $df->{"/dev/sda1"}, "found /dev/sda1" );
is( $df->{"/dev/sda1"}->{used_perc},  '15%',   "/dev/sda1 percent usage" );
is( $df->{"/dev/sda1"}->{free},       402687,  "/dev/sda1 free" );
is( $df->{"/dev/sda1"}->{mounted_on}, "/boot", "/dev/sda1 mounted_on" );
is( $df->{"/dev/sda1"}->{used},       67557,   "/dev/sda1 used" );
is( $df->{"/dev/sda1"}->{size},       495844,  "/dev/sda1 size" );

ok(
  exists $df->{"/dev/mapper/vg_c6test0232-lv_root"},
  "found /dev/mapper/vg_c6test0232-lv_root"
);
is( $df->{"/dev/mapper/vg_c6test0232-lv_root"}->{used_perc},
  '10%', "/dev/mapper/vg_c6test0232-lv_root percent usage" );
is( $df->{"/dev/mapper/vg_c6test0232-lv_root"}->{free},
  15489344, "/dev/mapper/vg_c6test0232-lv_root free" );
is( $df->{"/dev/mapper/vg_c6test0232-lv_root"}->{mounted_on},
  "/", "/dev/mapper/vg_c6test0232-lv_root mounted_on" );
is( $df->{"/dev/mapper/vg_c6test0232-lv_root"}->{used},
  1693244, "/dev/mapper/vg_c6test0232-lv_root used" );
is( $df->{"/dev/mapper/vg_c6test0232-lv_root"}->{size},
  18102140, "/dev/mapper/vg_c6test0232-lv_root size" );
