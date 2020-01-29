use strict;
use warnings;

use Test::More;
use Test::PerlTidy;

plan skip_all => 'these tests are for testing by the author'
  unless $ENV{AUTHOR_TESTING};

run_tests(
  exclude => [
    'Makefile.PL',                  '.build/',
    'blib/',                        'misc/',
    qr{xt/author/(?!perltidy\.t$)}, qr{xt/release/},
  ],
);
