#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings;
use Test::Output;

use File::Temp qw(tmpnam);
use Rex::Commands::Augeas;
use Rex::Commands::Run;

if ( can_run('augtool') ) {
  plan tests => 2;
}
else {
  plan skip_all => 'Could not find augtool command';
}

my $file       = tmpnam();
my $test_value = 'rex';

subtest 'Simplelines lens' => sub {
  plan tests => 7;

  Rex::Config->set_augeas_commands_prepend(
    [ "transform Simplelines incl $file", 'load', ] );

  my $path = '/files' . $file . '/1';

  is( -e $file, undef, 'test file does not exist yet' );

  # modify

  augeas modify => $path => $test_value;

  is( -e $file, 1, 'test file created' );

  # exists

  my $has_first_entry = augeas exists => $path;

  is( $has_first_entry, 1, 'first entry exists' );

  # get

  my $retrieved_value = augeas get => $path;

  is( $retrieved_value, $test_value, 'test value retrieved' );

  # dump

  stdout_is(
    sub { augeas dump => $path },
    qq($path = "$test_value"\n),
    'correct dump output'
  );

  # remove

  augeas remove => $path;

  my $still_has_first_entry = augeas exists => $path;

  is( $still_has_first_entry, 0, 'first entry removed' );

  unlink $file;

  is( -e $file, undef, 'test file cleaned up' );
};
