#!/usr/bin/env perl

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 2;
use Test::Warnings;

use English qw(-no_match_vars);
use File::Spec;
use Rex::Helper::Run;

my $cmd = $OSNAME eq 'MSWin32' ? 'cd' : 'pwd';

my $target_dir = File::Spec->tmpdir();
my $dir        = i_run $cmd, cwd => $target_dir;

is( $dir, $target_dir, 'switch to temp directory' );
