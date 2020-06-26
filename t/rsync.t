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

use Cwd qw(getcwd);
use File::Find;
use File::Spec::Functions qw(catfile rel2abs);
use File::Temp qw(tempdir);

plan tests => 2;

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
  my ( $source, $target ) = @_;
  my ( @expected, @result );

  # expected results
  find(
    {
      wanted => sub {
        s:^(t|.*/t)(?=/)::;
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
        push @result, $_ if length($_);
      },
      no_chdir => 1
    },
    $target
  );

  is_deeply( \@result, \@expected, 'synced dir matches' );
}

subtest 'local rsync with absolute path' => sub {
  my $cwd = getcwd();

  my $source = catfile( $cwd, 't/sync' );
  my $target = setup();

  sync $source, $target;

  test_results( $source, $target );
};

subtest 'local rsync with relative path' => sub {
  my $cwd = getcwd();

  my $source = 't/sync';
  my $target = setup();

  sync $source, $target;

  test_results( $source, $target );
};
