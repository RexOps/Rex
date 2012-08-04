use strict;
use warnings;

use Test::More tests => 11;
use Data::Dumper;

use_ok 'Rex';
use_ok 'Rex::Commands::File';
use_ok 'Rex::Commands::Fs';
use_ok 'Rex::Commands::Gather';
Rex::Commands::File->import;
Rex::Commands::Fs->import;
Rex::Commands::Gather->import;

file("test.txt",
   content => "blah blah\nfoo bar");

my $c = cat("test.txt");

ok($c, "cat");
ok($c =~ m/blah/, "file with content (1)");
ok($c =~ m/bar/, "file with content (2)");

Rex::Commands::Fs::unlink("test.txt");

ok(! is_file("test.txt"), "file removed");

file("test.txt",
   content => "blah blah\nbaaazzzz",
   mode => 777);

my %stats = Rex::Commands::Fs::stat("test.txt");
ok($stats{mode} eq "0777" || is_windows(), "fs chmod ok");

my $changed = 0;
append_if_no_such_line("test.txt", "change", qr{change}, 
   on_change => sub {
      $changed = 1;
   });

ok($changed == 1, "something was changed in the file");

append_if_no_such_line("test.txt", "change", qr{change}, 
   on_change => sub {
      $changed = 0;
   });

ok($changed == 1, "nothing was changed in the file");



Rex::Commands::Fs::unlink("test.txt");

