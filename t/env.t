#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 2;
use Test::Warnings;

use Rex::Commands::Run;

$::QUIET = 1;

my $s = run( 'perl', [ '-e', 'print $ENV{REX}' ], env => { 'REX' => 'XER' } );

like( $s, qr/XER/, "run with env" );
