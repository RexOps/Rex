#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings;
use Test::Exception;

use English qw(-no_match_vars);
use File::Spec;
use File::Temp qw(tempdir);
use Rex::Commands;
use Rex::Commands::File;
use Rex::Commands::Run;
use Rex::Commands::SCM;
use Rex::Helper::Run;

$::QUIET = 1;

my $git = can_run('git');

if ( defined $git ) {
  plan tests => 15;
}
else {
  plan skip_all => 'Can not find git command';
}

my $git_user_name  = 'Rex';
my $git_user_email = 'noreply@rexify.org';

my $empty_config_file = $OSNAME eq 'MSWin32' ? q() : File::Spec->devnull();

my $git_environment = {
  GIT_CONFIG_GLOBAL => $empty_config_file,
  GIT_CONFIG_SYSTEM => $empty_config_file,
};

ok( $git, "Found git command at $git" );

my $git_version = i_run 'git version', env => $git_environment;
ok( $git_version, qq(Git version returned as '$git_version') );

my $test_repo_dir = tempdir( CLEANUP => 1 );
ok( -d $test_repo_dir, "$test_repo_dir is the test repo directory now" );

my $test_repo_name              = 'test_repo';
my $test_initial_commit_message = 'initial_commit';

my $test_branch_name           = 'test_branch';
my $test_branch_commit_message = 'origin_branch_commit';

prepare_test_repo($test_repo_dir);
git_repo_ok($test_repo_dir);

set repository => $test_repo_name, url => $test_repo_dir;

subtest 'clone into non-existing directory', sub {
  plan tests => 6;

  my $clone_target_dir = init_test();

  ok( -d $clone_target_dir, "$clone_target_dir could be created" );

  rmdir $clone_target_dir;

  ok( !-d $clone_target_dir, "$clone_target_dir does not exist now" );

  lives_ok { checkout $test_repo_name, path => $clone_target_dir }
  'cloning into non-existing directory';

  git_repo_ok($clone_target_dir);
};

subtest 'clone into existing directory', sub {
  plan tests => 5;

  my $clone_target_dir = init_test();

  ok( -d $clone_target_dir,
    "$clone_target_dir is the clone target directory now" );

  lives_ok { checkout $test_repo_name, path => $clone_target_dir }
  'cloning into existing directory';

  git_repo_ok($clone_target_dir);
};

subtest 'checkout new commits', sub {
  plan tests => 4;

  my $clone_target_dir = init_test( clone => TRUE );

  my $test_commit_message = 'new_origin_commit';

  create_commit( directory => $test_repo_dir, message => $test_commit_message );

  lives_ok {
    checkout $test_repo_name,
      path => $clone_target_dir,
  }
  'pulling new commit';

  git_last_commit_message_ok( $clone_target_dir, $test_commit_message );

  reset_test_repo();
};

subtest 'checkout new commits with rebase', sub {
  plan tests => 4; ## no critic (ProhibitDuplicateLiteral)

  my $clone_target_dir = init_test( clone => TRUE );

  create_commit(
    directory => $test_repo_dir,
    message   => 'new_oriting_commit_rebase'
  );

  my $test_commit_message = 'new_local_commit';

  create_commit(
    directory => $clone_target_dir,
    message   => $test_commit_message
  );

  lives_ok {
    checkout $test_repo_name,
      path   => $clone_target_dir,
      rebase => TRUE,
  }
  'pulling new commit with rebase';

  git_last_commit_message_ok( $clone_target_dir, $test_commit_message );

  reset_test_repo();
};

subtest 'clone a branch', sub {
  plan tests => 5; ## no critic (ProhibitDuplicateLiteral)

  my $clone_target_dir = init_test();

  lives_ok {
    checkout $test_repo_name,
      path   => $clone_target_dir,
      branch => $test_branch_name,
  }
  'cloning a branch';

  git_repo_ok($clone_target_dir);
  git_branch_ok( $clone_target_dir, $test_branch_name );
};

subtest 'checkout a branch after cloning', sub {
  plan tests => 6; ## no critic (ProhibitDuplicateLiteral)

  my $clone_target_dir = init_test( clone => TRUE );

  lives_ok {
    checkout $test_repo_name,
      path   => $clone_target_dir,
      branch => $test_branch_name,
  }
  'checking out a branch after cloning';

  git_repo_ok($clone_target_dir);
  git_branch_ok( $clone_target_dir, $test_branch_name );
};

subtest 'checkout new commits from a branch', sub {
  plan tests => 4; ## no critic (ProhibitDuplicateLiteral)

  my $clone_target_dir = init_test( clone => TRUE );

  lives_ok {
    checkout $test_repo_name,
      path   => $clone_target_dir,
      branch => $test_branch_name,
  }
  'pulling new commit from branch';

  git_branch_ok( $clone_target_dir, $test_branch_name );
  git_last_commit_message_ok( $clone_target_dir, $test_branch_commit_message );
};

subtest 'checkout new commits from a branch with rebase', sub {
  plan tests => 5; ## no critic (ProhibitDuplicateLiteral)

  my $clone_target_dir = init_test( clone => TRUE );

  my $test_commit_message = 'local_branch_commit';

  create_commit(
    directory => $clone_target_dir,
    message   => $test_commit_message
  );

  git_last_commit_message_ok( $clone_target_dir, $test_commit_message );

  lives_ok {
    checkout $test_repo_name,
      path   => $clone_target_dir,
      branch => $test_branch_name,
      rebase => TRUE,
  }
  'pulling new commit from branch with rebase';

  git_branch_ok( $clone_target_dir, $test_branch_name );
  git_last_commit_message_ok( $clone_target_dir, $test_commit_message );
};

sub prepare_test_repo {
  my $directory = shift;

  i_run 'git init', cwd => $directory, env => $git_environment;

  configure_git_user($directory);

  my $default_branch = i_run 'git symbolic-ref HEAD',
    cwd => $directory,
    env => $git_environment;

  $default_branch =~ s{refs/heads/}{}msx;

  create_commit(
    directory => $directory,
    message   => $test_initial_commit_message
  );

  i_run "git checkout -b $test_branch_name",
    cwd => $directory,
    env => $git_environment;

  create_commit(
    directory => $directory,
    message   => $test_branch_commit_message
  );

  i_run "git checkout $default_branch",
    cwd => $directory,
    env => $git_environment;

  return;
}

sub git_repo_ok {
  my $directory = shift;

  ok( -d $directory, "$directory exists" );
  ok(
    -d File::Spec->join( $directory, q(.git) ),
    "$directory has .git subdirectory"
  );

  lives_ok {
    i_run 'git rev-parse --git-dir', cwd => $directory, env => $git_environment
  }
  "$directory looks like a git repository now";

  return;
}

sub configure_git_user {
  my $directory = shift;

  i_run "git config user.name $git_user_name",
    cwd => $directory,
    env => $git_environment;

  i_run "git config user.email $git_user_email",
    cwd => $directory,
    env => $git_environment;

  return;
}

sub init_test {
  my %opts = @_;

  my $clone_target_dir = tempdir( CLEANUP => 1 );

  if ( $opts{clone} ) {
    lives_ok {
      checkout $test_repo_name,
        path => $clone_target_dir,
    }
    'cloning the repo';

    configure_git_user($clone_target_dir);
  }

  return $clone_target_dir;
}

sub git_last_commit_message_ok {
  my ( $directory, $expected_commit_message ) = @_;

  my $last_commit_message = i_run 'git log --oneline -1 --format=%s',
    cwd => $directory,
    env => $git_environment;

  is( $last_commit_message, $expected_commit_message,
    'got correct last commit message' );

  return;
}

sub reset_test_repo {
  i_run 'git reset --hard HEAD~1',
    cwd => $test_repo_dir,
    env => $git_environment;

  git_last_commit_message_ok( $test_repo_dir, $test_initial_commit_message );

  return;
}

sub git_branch_ok {
  my ( $directory, $expected_branch ) = @_;

  my $current_branch = i_run 'git rev-parse --abbrev-ref HEAD',
    cwd => $directory,
    env => $git_environment;

  is( $current_branch, $expected_branch, 'got correct current branch name' );

  return;
}

sub create_commit {
  my %opts = @_;

  my $directory = $opts{directory};
  my $message   = my $filename = $opts{message};

  my $path = File::Spec->join( $directory, $filename );

  file $path;

  i_run "git add $filename",
    cwd => $directory,
    env => $git_environment;

  i_run "git commit -m $message",
    cwd => $directory,
    env => $git_environment;

  return;
}
