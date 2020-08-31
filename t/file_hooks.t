use strict;
use warnings;

use Test::More tests => 22;
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

register_function_hooks {
  before        => { file => \&before_hook, },
  before_change => { file => \&before_change_hook, },
  after_change  => { file => \&after_change_hook, },
  after         => { file => \&after_hook, },
};

sub before_hook {
  my ( $file, @options ) = @_;
  my $params = {@options};

  my $expected_params;

  if ( exists $params->{content} ) {
    $expected_params = {
      ensure  => 'present',
      content => $test_content,
    };
  }
  else {
    $expected_params = { ensure => 'absent', };
  }

  $before += 1;

  is( $file, $test_file, 'before - filename is correct' );

  cmp_deeply( $params, $expected_params,
    'before - received expected parameters' );

  $params->{mode} = $test_mode;

  return $file, %{$params};
}

sub before_change_hook {
  my ( $file, @options ) = @_;
  my $params = {@options};

  my $expected_params;

  if ( exists $params->{content} ) {
    $expected_params = {
      ensure  => 'present',
      content => $test_content,
      mode    => $test_mode,
    };
  }
  else {
    $expected_params = {
      ensure => 'absent',
      mode   => $test_mode,
    };
  }

  $before_change += 1;

  is( $file, $test_file, 'before_change - filename is correct' );

  cmp_deeply( $params, $expected_params,
    'before_change - received expected parameters' );
}

sub after_change_hook {
  my ( $file, @options ) = @_;
  my $result = pop @options;
  my $params = {@options};

  my $expected_params;

  if ( exists $params->{content} ) {
    $expected_params = {
      ensure  => 'present',
      content => $test_content,
      mode    => $test_mode,
    };
  }
  else {
    $expected_params = {
      ensure => 'absent',
      mode   => $test_mode,
    };
  }

  $after_change += 1;

  is( $file, $test_file, 'after_change - filename is correct' );

  cmp_deeply( $params, $expected_params,
    'after_change - received expected parameters' );
}

sub after_hook {
  my ( $file, @options ) = @_;
  my $result = pop @options;
  my $params = {@options};

  my $expected_params;

  if ( exists $params->{content} ) {
    $expected_params = {
      ensure  => 'present',
      content => $test_content,
      mode    => $test_mode,
    };
  }
  else {
    $expected_params = {
      ensure => 'absent',
      mode   => $test_mode,
    };
  }

  $after += 1;

  is( $file, $test_file, 'after - filename is correct' );

  cmp_deeply( $params, $expected_params,
    'after - received expected parameters' );
}

stderr_like( sub { file $test_file, content => $test_content },
  qr{^$}, 'stderr is empty' );

stderr_like( sub { file $test_file, ensure => 'absent' },
  qr{^$}, 'stderr is empty' );

is( $before,        2, 'before hook ran' );
is( $before_change, 2, 'before_change hook ran' );
is( $after_change,  2, 'after_change hook ran' );
is( $after,         2, 'after hook ran' );
