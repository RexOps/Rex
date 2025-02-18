#!/usr/bin/env perl

use v5.12.5;
use warnings;

use Test::More;

our $VERSION = '9999.99.99_99'; # VERSION
use autodie;

use File::Find;
use File::Temp qw(tempdir);
use Rex::Task;
use Rex::Commands::Sync;
use Test::Deep;

subtest 'should sync_up' => sub {
  my $source = 't/sync';
  my $target = prepare_directory();

  run_task(
    sub {
      sync_up $source, $target;
    }
  );

  compare_contents( $source, $target );
};

subtest 'should sync_up with excludes' => sub {
  my $source = 't/sync';
  my $target = prepare_directory();

  # NOTE: file4 should not be excluded, as it is nested
  run_task(
    sub {
      sync_up $source, $target,
        { exclude => [ 'dir/file2', 'file4', 'dir with spaces' ] };
    }
  );

  compare_contents( $source, $target,
    [ '/dir/file2', '/dir with spaces', '/dir with spaces/file3' ] );
};

subtest 'should sync_down' => sub {
  my $source = 't/sync';
  my $target = prepare_directory();

  run_task(
    sub {
      sync_down $source, $target;
    }
  );

  compare_contents( $source, $target );
};

subtest 'should sync_down with excludes' => sub {
  my $source = 't/sync';
  my $target = prepare_directory();

  # NOTE: file4 should not be excluded, as it is nested
  run_task(
    sub {
      sync_down $source, $target,
        { exclude => [ 'dir/file2', 'file4', 'dir with spaces' ] };
    }
  );

  compare_contents( $source, $target,
    [ '/dir/file2', '/dir with spaces', '/dir with spaces/file3' ] );
};

sub prepare_directory {
  my $target = tempdir( CLEANUP => 1 );
  die unless -d $target;

  return $target;
}

sub run_task {
  my ($func) = @_;

  my $task = Rex::Task->new(
    name => 'sync_test',
    func => $func,
  );

  $task->run('<local>');
}

sub compare_contents {
  my ( $source, $target, $excluded ) = @_;
  $excluded //= [];
  my %excluded_map = map { $_ => 1 } @{$excluded};

  # test sync results
  my ( @expected, @result );

  # expected results
  find(
    {
      wanted => sub {
        s/$source//;
        return unless length;
        return if $excluded_map{$_};
        push @expected, $_;
      },
      no_chdir => 1
    },
    $source
  );

  # actual results
  find(
    {
      wanted => sub {
        s/$target//;
        return unless length;
        push @result, $_;
      },
      no_chdir => 1
    },
    $target
  );

  cmp_deeply( \@result, set(@expected), 'synced dir matches' );
}

done_testing;

