#!/usr/bin/env perl

use v5.12.5;
use warnings;

use Test::More tests => 1;

use Rex::Commands::Fs;
use Test::Exception;

subtest 'stat fails for a nonexistent file', sub {
  plan tests => 2;

  my $fake_file = 'file_that_does_not_exist';

  is( -e $fake_file, undef, 'test file does not exist' );

  throws_ok { Rex::Commands::Fs::stat($fake_file) }
  qr/^Can't stat $fake_file/, 'Stat for a nonexistent file throws an exception';
};
