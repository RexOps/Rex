use strict;
use warnings;

use Cwd 'getcwd';
my $cwd = getcwd;

BEGIN {
   use Test::More tests => 44;
   use Data::Dumper;

   use_ok 'Rex';
   use_ok 'Rex::Commands::File';
   use_ok 'Rex::Commands::Fs';
   use_ok 'Rex::Commands::Gather';
   use_ok 'Rex::Config';
   Rex::Commands::File->import;
   Rex::Commands::Fs->import;
   Rex::Commands::Gather->import;
};

if($ENV{rex_LOCALTEST}) {
   Rex::Config->set_executor_for(perl => "/Users/jan/perl5/perlbrew/perls/perl-5.14.2/bin/perl");
}

my $tmp_dir = "/tmp";
if($^O =~ m/^MSWin/) {
   $tmp_dir = $ENV{TMP};
}

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

append_if_no_such_line("$cwd/test.txt",
   line => "dream-breaker",
   regexp => qr{^dream-breaker$});

$content = cat("$cwd/test.txt");
ok($content =~ m/dream\-breaker/gms, "found dream-breaker");

append_if_no_such_line("$cwd/test.txt",
   line => "#include /etc/sudoers.d/*.conf",
   regexp => qr{^#include /etc/sudoers.d/*.conf$});

$content = cat("$cwd/test.txt");
ok($content =~ m/#include \/etc\/sudoers\.d\/\*\.conf/gms, "found sudoers entry");

append_if_no_such_line("$cwd/test.txt",
   line => 'silly with "quotes"');

$content = cat("$cwd/test.txt");
ok($content =~ m/silly with "quotes"/gms, "found entry with quotes");

append_if_no_such_line("$cwd/test.txt",
   line => "#include /etc/sudoers.d/*.conf");

my @content = split(/\n/, cat("$cwd/test.txt"));
ok($content[-1] ne "#include /etc/sudoers.d/*.conf", "last entry is not #include ...");

append_if_no_such_line("$cwd/test.txt", 'KEY="VAL"');
$content = cat("$cwd/test.txt");
ok($content =~ m/KEY="VAL"/gms, "found KEY=VAL");

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


file "$tmp_dir/test-sed.txt",
   content => "this is a sed test file\nthese are just some lines\n0505\n0606\n0707\n'foo'\n/etc/passwd\n\"baz\"\n{klonk}\nfoo bar\n\\.-~'[a-z]\$ foo {1} /with/some/slashes \%\&()?\n|.-\\~'[a-z]\$ bar {2} /with/more/slashes \%\&()?\n";

sed qr/fo{2} bar/, "baz bar", "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/baz bar/, "sed replaced foo bar");

sed qr/^\\\.\-\~'\[a\-z\]\$ foo \{1\} \/with\/some\/slashes/, "got replaced", "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/got replaced/, "sed replaced strange chars");

sed qr/^\|\.\-\\\~'\[a\-z\]\$ BAR \{2\} \/with\/more\/slashes/i, "got another replace", "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/got another replace/, "sed replaced strange chars");

my @lines = split(/\n/, $content);
ok($lines[-1] =~ m/^got another replace/, "last line was successfully replaced");
ok($lines[-2] =~ m/^got replaced/, "second last line was successfully replaced");
ok($lines[-4] =~ m/^\{klonk\}/, "fourth last line untouched");

sed qr{0606}, "6666", "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/6666/, "sed replaced 0606");

sed qr{'foo'}, "'bar'", "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/'bar'/, "sed replaced 'foo'");

sed qr{/etc/passwd}, "/etc/shadow", "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/\/etc\/shadow/, "sed replaced /etc/passwd");

sed qr{"baz"}, '"boooooz"', "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/"boooooz"/, "sed replaced baz");

sed qr/{klonk}/, '{plonk}', "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/{plonk}/, "sed replaced {klonk}");

sed qr/{klonk}/, '{plonk}', "$tmp_dir/test-sed.txt";
$content = cat "$tmp_dir/test-sed.txt";
ok($content =~ m/{plonk}/, "sed replaced {klonk}");

file "$tmp_dir/multiline.txt", content => "this is\na test.\n";
sed qr/is\sa test/msi, "no one\nknows!", "$tmp_dir/multiline.txt", multiline => 1;
$content = cat "$tmp_dir/multiline.txt";
is($content,  "this no one\nknows!.\n", "multiline replacement");

unlink "$tmp_dir/multiline.txt";
