#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;

use Rex::Commands;
use Rex::Commands::Run;

$::QUIET = 1;

my $command = ( $^O =~ /MSWin/ ) ? 'dir' : 'ls -l';
run($command);

my $s = last_command_output();
like( $s, qr/ChangeLog/ms );

$command .= ' t';
run($command);

$s = last_command_output();
unlike( $s, qr/ChangeLog/ms );
like( $s, qr/auth\.t/ms );
