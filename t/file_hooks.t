#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;
use Test::Deep;
use Test::Output;

use File::Temp;
use Rex::Commands::File;
use Rex::Hook;

$::QUIET = 1;

my ( $before, $before_change, $after_change, $after );
my $test_file    = File::Temp->new()->filename();
my $test_mode    = '600';
my $test_content = 'test content';
my $test_source  = 't/commands/file/test.tpl';

register_function_hooks {
  before        => { file => \&before_hook, },
  before_change => { file => \&before_change_hook, },
  after_change  => { file => \&after_change_hook, },
  after         => { file => \&after_hook, },
};

my %code_for = (
  'file content' => sub { file $test_file, content => $test_content },
  'file source'  => sub { file $test_file, source  => $test_source },
  'file absent'  => sub { file $test_file, ensure  => 'absent' },
);

for my $test_case ( keys %code_for ) {
  subtest $test_case => sub {
    my $test_code = $code_for{$test_case};

    $before = $before_change = $after_change = $after = 0;

    stderr_like { $test_code->() } qr{^$}, 'stderr is empty';

    is( $before,        1, 'before hook ran' );
    is( $before_change, 1, 'before_change hook ran' );
    is( $after_change,  1, 'after_change hook ran' );
    is( $after,         1, 'after hook ran' );
  };
}

sub expected_params {
  my $params = shift;
  my ( undef, undef, undef, $subroutine ) = caller 1;

  my $expected_params = { ensure => 'present', };

  if ( exists $params->{content} ) {
    $expected_params->{content} = $test_content;
  }
  elsif ( exists $params->{source} ) {
    $expected_params->{source} = $test_source;
  }
  else {
    $expected_params = { ensure => 'absent', };
  }

  if ( $subroutine ne 'main::before_hook' ) {
    $expected_params->{mode} = $test_mode;
  }

  return $expected_params;
}

sub before_hook {
  my ( $file, @options ) = @_;
  my $params = {@options};

  $before += 1;

  is( $file, $test_file, 'before - filename is correct' );

  cmp_deeply(
    $params,
    expected_params($params),
    'before - received expected parameters',
  );

  $params->{mode} = $test_mode;

  return $file, %{$params};
}

sub before_change_hook {
  my ( $file, @options ) = @_;
  my $params = {@options};

  $before_change += 1;

  is( $file, $test_file, 'before_change - filename is correct' );

  cmp_deeply(
    $params,
    expected_params($params),
    'before_change - received expected parameters',
  );
}

sub after_change_hook {
  my ( $file, @options ) = @_;
  my $result = pop @options;
  my $params = {@options};

  $after_change += 1;

  is( $file, $test_file, 'after_change - filename is correct' );

  cmp_deeply(
    $params,
    expected_params($params),
    'after_change - received expected parameters',
  );
}

sub after_hook {
  my ( $file, @options ) = @_;
  my $result = pop @options;
  my $params = {@options};

  $after += 1;

  is( $file, $test_file, 'after - filename is correct' );

  cmp_deeply(
    $params,
    expected_params($params),
    'after - received expected parameters',
  );
}
