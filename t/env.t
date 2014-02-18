use Test::More tests => 2;

use_ok 'Rex::Commands::Run';

Rex::Commands::Run->import;

if($^O =~ m/^MSWin/) {
   ok(1==1, "skipped for winfows");
}
else {
   my $s = run("printenv REX", env => { 'REX' => 'XER' } );
   ok($s =~ m/XER/, "run with env");
}
