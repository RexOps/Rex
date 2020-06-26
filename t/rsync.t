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
use File::Basename qw(dirname);
use File::Find;
use File::Temp qw(tempdir);

my %source_for = (
  'rsync with absolute path'           => realpath('t/sync'),
  'rsync with relative path'           => 't/sync',
  'rsync with spaces in absolute path' => realpath('t/sync/dir with spaces'),
  'rsync with spaces in relative path' => 't/sync/dir with spaces',
);

plan tests => scalar keys %source_for;

for my $scenario ( sort keys %source_for ) {
  test_rsync( $scenario, $source_for{$scenario} );
}

sub test_rsync {
  my ( $scenario, $source ) = @_;

  subtest $scenario => sub {
    my $target = tempdir( CLEANUP => 1 );

    # test target directory
    ok( -d $target, "$target is a directory" );

    opendir( my $DIR, $target );
    my @contents = readdir $DIR;
    closedir $DIR;

    my @empty = qw(. ..);

    is_deeply( \@contents, \@empty, "$target is empty" );

    # sync contents
    sync $source, $target;

    # test sync results
    my ( @expected, @result );

    my $prefix = dirname($source);

    # expected results
    find(
      {
        preprocess => sub { sort @_ },
        wanted     => sub {
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
        preprocess => sub { sort @_ },
        wanted     => sub {
          s/$target//;
          push @result, $_ if length($_);
        },
        no_chdir => 1
      },
      $target
    );

    is_deeply( \@result, \@expected, 'synced dir matches' );
  }
}
