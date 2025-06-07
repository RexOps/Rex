#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings;
use Test::Deep;

use Rex::Hardware::Memory;

$::QUIET = 1;

my @test_cases = (
  {
    name             => 'FreeBSD sample 4 elements',
    top_output       => 'Mem: 12M Active, 34M Inact, 56M Wired, 78M Free',
    expected_results => {
      active => '12M',
      inact  => '34M',
      wired  => '56M',
      free   => '78M',
    },
  },
  {
    name       => 'FreeBSD sample 5 elements',
    top_output =>
      'Mem: 123K Active, 456M Inact, 789M Wired, 1011K Buf, 1213M Free',
    expected_results => {
      active => '123K',
      inact  => '456M',
      wired  => '789M',
      buf    => '1011K',
      free   => '1213M',
    },
  },
  {
    name       => 'FreeBSD sample 6 elements',
    top_output =>
      'Mem: 1415K Active, 1617M Inact, 1819M Laundry, 2021K Wired, 2223M Buf, 2425M Free',
    expected_results => {
      active  => '1415K',
      inact   => '1617M',
      laundry => '1819M',
      wired   => '2021K',
      buf     => '2223M',
      free    => '2425M',
    },
  },
);

plan tests => 1 + scalar @test_cases;

for my $case (@test_cases) {
  cmp_deeply(
    Rex::Hardware::Memory::__parse_top_output( $case->{top_output} ),
    $case->{expected_results},
    $case->{name}
  );
}
