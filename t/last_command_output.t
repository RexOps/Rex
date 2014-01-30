use Test::More tests => 5;

use_ok 'Rex::Commands';
use_ok 'Rex::Commands::Run';

Rex::Commands->import;
Rex::Commands::Run->import;

if($^O =~ /MSWin/) {
   run("dir");
}
else {
   run("ls -l");
}

my $s = last_command_output();
ok($s =~ m/Makefile\.PL/gms);

if($^O =~ /MSWin/) {
   run("dir t");
}
else {
   run("ls -l t");
}

$s = last_command_output();
ok($s !~ m/Makefile\.PL/gms);
ok($s =~ m/base\.t/gms);
