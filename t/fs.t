#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 5;

use File::Spec;
use File::Temp;
use Rex::Commands::Fs;
use Test::Exception;
use Test::Warnings;

subtest 'stat fails for a nonexistent file', sub {
  plan tests => 2;

  my $fake_file = 'file_that_does_not_exist';

  is( -e $fake_file, undef, 'test file does not exist' );

  throws_ok { Rex::Commands::Fs::stat($fake_file) }
  qr/^Can't stat $fake_file/, 'Stat for a nonexistent file throws an exception';
};

my %path_for = (
  'absolute path' => scalar tmpnam(),
  'relative path' => 'rex_mkdir_test_sub',
);

for my $case ( keys %path_for ) {
  subtest "mkdir with $case", sub {
    plan tests => 4;

    my $path = $path_for{$case};

    # check prerequisites
    ok( defined $path, "$path is defined" );
    ok( !-e $path,     "$path doesn't exist yet" );

    # create directory
    Rex::Commands::Fs::mkdir($path);

    ok( -d $path, "$path is a directory now" );

    # clean up
    CORE::rmdir $path;

    ok( !-e $path, "$path doesn't exist anymore" );
  };
}

subtest 'no warnings for splitting the path of the root directory', sub {
  plan tests => 1;

  ok( Rex::Commands::Fs::__splitdir( File::Spec->rootdir() ),
    'splitting up path of the root directory' );
};
