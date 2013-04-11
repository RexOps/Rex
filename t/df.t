use strict;
use warnings;

use Test::More tests => 37;
use Data::Dumper;


use_ok 'Rex::Commands::Fs';

my @lines = eval { local(@ARGV) = ("t/df.out2"); <>; };

my $df = Rex::Commands::Fs::_parse_df(@lines);

ok(exists $df->{tmpfs}, "found tmpfs");
ok($df->{tmpfs}->{used_perc} eq '0%', "tmpfs percent usage");
ok($df->{tmpfs}->{free} == 255160, "tmpfs free");
ok($df->{tmpfs}->{mounted_on} eq "/dev/shm", "tmpfs mounted_on");
ok($df->{tmpfs}->{used} == 0, "tmpfs used");
ok($df->{tmpfs}->{size} == 255160, "tmpfs size");

ok(exists $df->{"/dev/sda1"}, "found /dev/sda1");
ok($df->{"/dev/sda1"}->{used_perc} eq '15%', "/dev/sda1 percent usage");
ok($df->{"/dev/sda1"}->{free} == 402687, "/dev/sda1 free");
ok($df->{"/dev/sda1"}->{mounted_on} eq "/boot", "/dev/sda1 mounted_on");
ok($df->{"/dev/sda1"}->{used} == 67557, "/dev/sda1 used");
ok($df->{"/dev/sda1"}->{size} == 495844, "/dev/sda1 size");

ok(exists $df->{"/dev/sda2"}, "found /dev/sda2");
ok($df->{"/dev/sda2"}->{used_perc} eq '10%', "/dev/sda2 percent usage");
ok($df->{"/dev/sda2"}->{free} == 15489344, "/dev/sda2 free");
ok($df->{"/dev/sda2"}->{mounted_on} eq "/", "/dev/sda2 mounted_on");
ok($df->{"/dev/sda2"}->{used} == 1693244, "/dev/sda2 used");
ok($df->{"/dev/sda2"}->{size} == 18102140, "/dev/sda2 size");


@lines = ();
$df = {};

@lines = eval { local(@ARGV) = ("t/df.out1"); <>; };

$df = Rex::Commands::Fs::_parse_df(@lines);

ok(exists $df->{tmpfs}, "found tmpfs");
ok($df->{tmpfs}->{used_perc} eq '0%', "tmpfs percent usage");
ok($df->{tmpfs}->{free} == 255160, "tmpfs free");
ok($df->{tmpfs}->{mounted_on} eq "/dev/shm", "tmpfs mounted_on");
ok($df->{tmpfs}->{used} == 0, "tmpfs used");
ok($df->{tmpfs}->{size} == 255160, "tmpfs size");

ok(exists $df->{"/dev/sda1"}, "found /dev/sda1");
ok($df->{"/dev/sda1"}->{used_perc} eq '15%', "/dev/sda1 percent usage");
ok($df->{"/dev/sda1"}->{free} == 402687, "/dev/sda1 free");
ok($df->{"/dev/sda1"}->{mounted_on} eq "/boot", "/dev/sda1 mounted_on");
ok($df->{"/dev/sda1"}->{used} == 67557, "/dev/sda1 used");
ok($df->{"/dev/sda1"}->{size} == 495844, "/dev/sda1 size");

ok(exists $df->{"/dev/mapper/vg_c6test0232-lv_root"}, "found /dev/mapper/vg_c6test0232-lv_root");
ok($df->{"/dev/mapper/vg_c6test0232-lv_root"}->{used_perc} eq '10%', "/dev/mapper/vg_c6test0232-lv_root percent usage");
ok($df->{"/dev/mapper/vg_c6test0232-lv_root"}->{free} == 15489344, "/dev/mapper/vg_c6test0232-lv_root free");
ok($df->{"/dev/mapper/vg_c6test0232-lv_root"}->{mounted_on} eq "/", "/dev/mapper/vg_c6test0232-lv_root mounted_on");
ok($df->{"/dev/mapper/vg_c6test0232-lv_root"}->{used} == 1693244, "/dev/mapper/vg_c6test0232-lv_root used");
ok($df->{"/dev/mapper/vg_c6test0232-lv_root"}->{size} == 18102140, "/dev/mapper/vg_c6test0232-lv_root size");


