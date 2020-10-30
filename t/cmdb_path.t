#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 3;

use Cwd qw(realpath);
use File::Spec;
use Rex::CMDB;
use Rex::Commands;
use Rex::Hardware;
use Test::Deep qw(cmp_deeply);

my $cmdb_path           = realpath( File::Spec->join( 't', 'cmdb' ) );
my %hw_info             = Rex::Hardware->get('Host');
my $os                  = Rex::Hardware::Host->get_operating_system();
my $environment         = environment;
my @test_servers        = ( undef, 'foo' );
my $cmdb_type           = 'YAML';
my $host_macro_filename = '{hostname}.yml';
my $default_filename    = 'default.yml';

sub get_host_filename {
  my $server   = shift;
  my $hostname = $server // $hw_info{Host}{hostname};
  return ( $hostname, "$hostname.yml" );
}

subtest 'Set CMDB path as scalar' => sub {
  my $cmdb_provider = set(
    cmdb => {
      type => $cmdb_type,
      path => $cmdb_path,
    },
  );

  for my $server (@test_servers) {
    my ( $hostname, $host_filename ) = get_host_filename($server);

    my @cmdb_files     = $cmdb_provider->_get_cmdb_files( undef, $server );
    my @expected_files = (
      File::Spec->join( $cmdb_path, $environment, $host_filename ),
      File::Spec->join( $cmdb_path, $environment, $default_filename ),
      File::Spec->join( $cmdb_path, $host_filename ),
      File::Spec->join( $cmdb_path, $default_filename ),
    );

    cmp_deeply( \@cmdb_files, \@expected_files,
      "scalar CMDB path for $hostname" );
  }
};

subtest 'Set CMDB path as array reference' => sub {
  my $os_macro  = '{operatingsystem}';
  my $env_macro = '{environment}';

  my $cmdb_provider = set(
    cmdb => {
      type => $cmdb_type,
      path => [
        File::Spec->join( $cmdb_path, $os_macro,  $host_macro_filename ),
        File::Spec->join( $cmdb_path, $os_macro,  $default_filename ),
        File::Spec->join( $cmdb_path, $env_macro, $host_macro_filename ),
        File::Spec->join( $cmdb_path, $env_macro, $default_filename ),
        File::Spec->join( $cmdb_path, $host_macro_filename ),
        File::Spec->join( $cmdb_path, $default_filename ),
      ],
    },
  );

  for my $server (@test_servers) {
    my ( $hostname, $host_filename ) = get_host_filename($server);

    my @cmdb_files     = $cmdb_provider->_get_cmdb_files( undef, $server );
    my @expected_files = (
      File::Spec->join( $cmdb_path, $os,          $host_filename ),
      File::Spec->join( $cmdb_path, $os,          $default_filename ),
      File::Spec->join( $cmdb_path, $environment, $host_filename ),
      File::Spec->join( $cmdb_path, $environment, $default_filename ),
      File::Spec->join( $cmdb_path, $host_filename ),
      File::Spec->join( $cmdb_path, $default_filename ),
    );

    cmp_deeply( \@cmdb_files, \@expected_files,
      "arrayref CMDB path for $hostname" );
  }
};

subtest 'Set CMDB path as code reference' => sub {
  my $cmdb_provider = set(
    cmdb => {
      type => $cmdb_type,
      path => sub {
        my ( $provider, $item, $server ) = @_;
        my @files = (
          File::Spec->join( $cmdb_path, $host_macro_filename ),
          File::Spec->join( $cmdb_path, $default_filename ),
        );
        return @files;
      },
    },
  );

  for my $server (@test_servers) {
    my ( $hostname, $host_filename ) = get_host_filename($server);

    my @cmdb_files     = $cmdb_provider->_get_cmdb_files( undef, $server );
    my @expected_files = (
      File::Spec->join( $cmdb_path, $host_filename ),
      File::Spec->join( $cmdb_path, $default_filename ),
    );

    cmp_deeply( \@cmdb_files, \@expected_files,
      "coderef CMDB path for $hostname" );
  }
};
