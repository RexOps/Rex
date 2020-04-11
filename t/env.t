use Test::More tests => 1;

use Rex::Commands::Run;

$::QUIET = 1;

SKIP: {
  skip 'Do not run tests on Windows', 1 if $^O =~ m/^MSWin/;

  my $s = run( q(perl -e 'print $ENV{REX}'), env => { 'REX' => 'XER' } );
  like( $s, qr/XER/, "run with env" );
}
