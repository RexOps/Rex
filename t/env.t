use Test::More;

use_ok 'Rex::Commands::Run';

$::QUIET = 1;

Rex::Commands::Run->import;

SKIP: {
  skip 'Do not run tests on Windows', 1 if $^O =~ m/^MSWin/;

  my $s = run( "printenv REX", env => { 'REX' => 'XER' } );
  like( $s, qr/XER/, "run with env" );
}

done_testing();
