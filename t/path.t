#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;

use Rex::Helper::Path;

my $path = Rex::Helper::Path::resolv_path( "/home/foo/bar/baz", 1 );
is( $path, "/home/foo/bar/baz", "local test absolute path" );

SKIP: {
  skip 'No home directory tests for Windows.', 2 if $^O =~ m/^MSWin/;

  $path = Rex::Helper::Path::resolv_path( "~/bar/baz", 1 );
  like( $path, qr{^/}, "expanded \$HOME" );

  $path = Rex::Helper::Path::resolv_path("~/bar/baz");
  like( $path, qr{^/}, "expanded \$HOME - no local" );
}
