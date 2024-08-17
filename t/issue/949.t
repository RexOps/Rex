#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;
use Test::Warnings;

use Rex::Commands;
use Rex::Virtualization;

eval {
  my $v = Rex::Virtualization->create();
  1;
} or do {
  like $@,
    qr/^No virtualization provider set.\nPlease use `set virtualization => 'YourProvider'/,
    "Got right error message if no provider is set.";
};

set virtualization => "Goo";

eval {
  my $v = Rex::Virtualization->create();
  1;
} or do {
  like $@,
    qr/^Failed loading given virtualization module\.\nTried to load \<Rex::Virtualization::Goo\>/,
    "Got right error message if module loading failed.";
};
