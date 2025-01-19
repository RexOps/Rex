#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use English qw(-no_match_vars);
use Test::More;
use Test::Warnings;

use Rex::Commands::Run;

plan tests => 3;

subtest 'simple command output', sub {
  my $output = run 'echo 1';

  if ( $OSNAME eq 'MSWin32' ) {
    $output =~ s/[ ]$//msx;
  }

  is( $output, 1, 'correct output' );
};

subtest 'command with arguments', sub {
  my $output = run 'perl', [ '-e', 'print 1' ];

  is( $output, 1, 'correct output with arguments' );
};
