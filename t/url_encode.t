#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 2;
use Test::Warnings;

use Rex::Helper::Encode;

my $input =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#+~*`´!\"§\$%&/()=?\\|<>,.-_'^°";
my $output =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789%23%2B%7E%2A%60%C2%B4%21%22%C2%A7%24%25%26%2F%28%29%3D%3F%5C%7C%3C%3E%2C%2E%2D_%27%5E%C2%B0";

is( Rex::Helper::Encode::url_encode($input),
  $output, "encode everything except a-z0-9_" );
