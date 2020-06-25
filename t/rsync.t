use strict;
use warnings;
use autodie;

use Cwd 'getcwd';
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Test::More;

use Rex::Commands::Rsync;
use Rex::Task;

# $Rex::Logger::debug = 1;

sub setup {
  my $target_dir = tempdir( CLEANUP => 1 );

  ok( -d $target_dir, "$target_dir is a directory" );

  opendir( my $DIR, $target_dir );
  my @contents = readdir $DIR;
  closedir $DIR;

  my @empty = qw(. ..);

  is_deeply( \@contents, \@empty, "$target_dir is empty" );

  return $target_dir;
}

sub test_results {
  my $target_dir = shift;

  # TODO: would be nice to actually compare the content for exact
  # match

  ok( -f catfile( $target_dir, 'sync', 'file1' ), 'file1 synced' );
  ok( -f catfile( $target_dir, 'sync', 'file2' ), 'file2 synced' );
  ok( -d catfile( $target_dir, 'sync', 'dir' ),   'dir synced' );

  ok( -f catfile( $target_dir, 'sync', 'dir', 'file3' ), 'file3 synced' );
  ok( -f catfile( $target_dir, 'sync', 'dir', 'file4' ), 'file4 synced' );
}

subtest 'rsync with absolute path' => sub {
  my $target_dir = setup();
  my $cwd        = getcwd;

  my $task = Rex::Task->new( name => 'rsync_absolute' );
  isa_ok( $task, 'Rex::Task', 'create teask object' );

  sync catfile( $cwd, 't/sync' ), $target_dir;

  test_results($target_dir);
};

subtest 'rsync with absolute path and wildcard' => sub {
  my $target_dir = setup();
  my $cwd        = getcwd;

  my $task = Rex::Task->new( name => 'rsync_absolute_wildcard' );
  isa_ok( $task, 'Rex::Task', 'create teask object' );

  sync catfile( $cwd, 't/sync/*' ), $target_dir;

  test_results($target_dir);
};

done_testing;
