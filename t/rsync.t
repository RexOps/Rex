use strict;
use warnings;
use autodie;

BEGIN {
  use Test::More;
  use Rex::Commands::Run;

  can_run('rsync') or plan skip_all => 'Could not find rsync command';

  eval 'use Rex::Commands::Rsync; 1'
    or plan skip_all => 'Could not load Rex::Commands::Rsync module';
}

use Cwd qw(realpath);
use File::Basename qw(basename dirname);
use File::Find;
use File::Temp qw(tempdir);
use Rex::Task;
use Test::Deep;

my %source_for = (
  'rsync with absolute path'             => realpath('t/sync'),
  'rsync with relative path'             => 't/sync',
  'rsync with spaces in absolute path'   => realpath('t/sync/dir with spaces'),
  'rsync with spaces in relative path'   => 't/sync/dir with spaces',
  'rsync with wildcard in absolute path' => realpath('t/sync/*'),
  'rsync with wildcard in relative path' => 't/sync/*',
);

plan tests => 2 * scalar keys %source_for;

for my $scenario ( sort keys %source_for ) {
  test_rsync( $scenario, $source_for{$scenario} );
  test_rsync( $scenario, $source_for{$scenario}, { download => 1 } );
}

sub test_rsync {
  my ( $scenario, $source, $options ) = @_;

  subtest $scenario => sub {
    my $target = tempdir( CLEANUP => 1 );

    # test target directory
    ok( -d $target, "$target is a directory" );

    opendir( my $DIR, $target );
    my @contents = readdir $DIR;
    closedir $DIR;

    my @empty = qw(. ..);

    cmp_deeply( \@contents, set(@empty), "$target is empty" );

    # sync contents
    my $task = Rex::Task->new(
      name => 'rsync_test',
      func => sub { sync $source, $target, $options },
    );

    $task->run('<local>');

    # test sync results
    my ( @expected, @result );

    my $prefix;

    if ( basename($source) =~ qr{\*} ) {
      $source = dirname($source);
      $prefix = $source;
    }
    else {
      $prefix = dirname($source);
    }

    # expected results
    find(
      {
        wanted => sub {
          s/$prefix//;
          push @expected, $_ if length($_);
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
          push @result, $_ if length($_);
        },
        no_chdir => 1
      },
      $target
    );

    cmp_deeply( \@result, set(@expected), 'synced dir matches' );
  }
}
