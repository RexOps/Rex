#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use English qw(-no_match_vars);
use Rex::Commands::Run;
use Test::More;

my $command;
my $uname = can_run('uname');

if ( $OSNAME =~ /MSWin/msx ) {
  $command = $uname;
}
else {
  my $path_with_spaces = '/tmp/path with spaces';
  mkdir $path_with_spaces;
  $command = File::Spec->join( $path_with_spaces, 'hello' );
  symlink $uname, $command;
}

diag $command;

run("$command");
is( $CHILD_ERROR, 0, 'command with spaces' );

run("$command -s");
is( $CHILD_ERROR, 0, 'command with spaces and args' );

done_testing;
