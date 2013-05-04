use strict;
use warnings;

use Cwd 'getcwd';
my $cwd = getcwd;

BEGIN {
   use Test::More tests => 25;
   use Data::Dumper;

   use_ok 'Rex';
   use_ok 'Rex::Commands::File';
   use_ok 'Rex::Commands::Fs';
   use_ok 'Rex::Commands::Gather';
   Rex::Commands::File->import;
   Rex::Commands::Fs->import;
   Rex::Commands::Gather->import;
};

file("$cwd/test.txt",
   content => "blah blah\nfoo bar");

my $c = cat("$cwd/test.txt");

ok($c, "cat");
ok($c =~ m/blah/, "file with content (1)");
ok($c =~ m/bar/, "file with content (2)");

Rex::Commands::Fs::unlink("$cwd/test.txt");

ok(! is_file("$cwd/test.txt"), "file removed");

file("$cwd/test.txt",
   content => "blah blah\nbaaazzzz",
   mode => 777);

my %stats = Rex::Commands::Fs::stat("$cwd/test.txt");
ok($stats{mode} eq "0777" || is_windows(), "fs chmod ok");

my $changed = 0;
my $content = cat("$cwd/test.txt");
ok($content !~ m/change/gms, "found change");

append_if_no_such_line("$cwd/test.txt", "change", qr{change}, 
   on_change => sub {
      $changed = 1;
   });

$content = cat("$cwd/test.txt");
ok($content =~ m/change/gms, "found change");

ok($changed == 1, "something was changed in the file");

append_if_no_such_line("$cwd/test.txt", "change", qr{change}, 
   on_change => sub {
      $changed = 0;
   });

ok($changed == 1, "nothing was changed in the file");

append_if_no_such_line("$cwd/test.txt", "change",
   on_change => sub {
      $changed = 0;
   });

ok($changed == 1, "nothing was changed in the file without regexp");

$content = cat("$cwd/test.txt");
ok($content !~ m/foobar/gms, "not found foobar");


append_if_no_such_line("$cwd/test.txt",
      line => "foobar",
);
$content = cat("$cwd/test.txt");
ok($content =~ m/foobar/gms, "found foobar");

append_if_no_such_line("$cwd/test.txt",
      line => "bazzada",
      regexp => qr{^foobar},
);
$content = cat("$cwd/test.txt");

ok($content !~ m/bazzada/gms, "found bazzada");

append_if_no_such_line("$cwd/test.txt",
      line => "tacktack",
      regexp => qr{blah blah}ms,
);
$content = cat("$cwd/test.txt");

ok($content !~ m/tacktack/gms, "not found tacktack");

append_if_no_such_line("$cwd/test.txt",
      line => "nothing there",
      regexp => [qr{blah blah}ms, qr{tzuhgjbn}ms],
);
$content = cat("$cwd/test.txt");

ok($content !~ m/nothing there/gms, "not found nothing there");

append_if_no_such_line("$cwd/test.txt",
      line => "this is there",
      regexp => [qr{qaywsx}ms, qr{tzuhgjbn}ms],
);
$content = cat("$cwd/test.txt");

ok($content =~ m/this is there/gms, "found this is there");



append_if_no_such_line("$cwd/test.txt",
      line => "bazzada",
      regexp => qr{^bazzada},
);
$content = cat("$cwd/test.txt");
ok($content =~ m/bazzada/gms, "found bazzada (2)");



file "file with space.txt",
   content => "file with space\n";

ok(is_file("file with space.txt"), "file with space exists");

$c = "";
$c = cat "file with space.txt";
ok($c =~ m/file with space/m, "found content of file with space");

Rex::Commands::Fs::unlink("$cwd/test.txt");
Rex::Commands::Fs::unlink("file with space.txt");

ok(! is_file("$cwd/test.txt"), "test.txt removed");
ok(! is_file("file with space.txt"), "file with space removed");
