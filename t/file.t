use strict;
use warnings;

use Cwd 'getcwd';
my $cwd = getcwd;

BEGIN {
  use Test::More tests => 45;
  use Data::Dumper;

  use_ok 'Rex';
  use_ok 'Rex::Commands::File';
  use_ok 'Rex::Commands::Fs';
  use_ok 'Rex::Commands::Gather';
  use_ok 'Rex::Config';
  Rex::Commands::File->import;
  Rex::Commands::Fs->import;
  Rex::Commands::Gather->import;
}

if ( $ENV{rex_LOCALTEST} ) {
  Rex::Config->set_executor_for(
    perl => "/Users/jan/perl5/perlbrew/perls/perl-5.14.2/bin/perl" );
}

my $tmp_dir = "/tmp";
if ( $^O =~ m/^MSWin/ ) {
  $tmp_dir = $ENV{TMP};
}

my $filename = "$cwd/test-$$.txt";

file( $filename, content => "blah blah\nfoo bar" );

my $c = cat($filename);

ok( $c,            "cat" );
ok( $c =~ m/blah/, "file with content (1)" );
ok( $c =~ m/bar/,  "file with content (2)" );

Rex::Commands::Fs::unlink($filename);

ok( !is_file($filename), "file removed" );

file(
  $filename,
  content => "blah blah\nbaaazzzz",
  mode    => 777
);

my %stats = Rex::Commands::Fs::stat($filename);
ok( $stats{mode} eq "0777" || is_windows(), "fs chmod ok" );

my $changed = 0;
my $content = cat($filename);
ok( $content !~ m/change/gms, "found change" );

append_if_no_such_line(
  $filename,
  "change",
  qr{change},
  on_change => sub {
    $changed = 1;
  }
);

$content = cat($filename);
ok( $content =~ m/change/gms, "found change" );

ok( $changed == 1, "something was changed in the file" );

append_if_no_such_line(
  $filename,
  line   => "dream-breaker",
  regexp => qr{^dream-breaker$}
);

$content = cat($filename);
ok( $content =~ m/dream\-breaker/gms, "found dream-breaker" );

append_if_no_such_line(
  $filename,
  line   => "#include /etc/sudoers.d/*.conf",
  regexp => qr{^#include /etc/sudoers.d/*.conf$}
);

$content = cat($filename);
ok( $content =~ m/#include \/etc\/sudoers\.d\/\*\.conf/gms,
  "found sudoers entry" );

append_if_no_such_line( $filename, line => 'silly with "quotes"' );

$content = cat($filename);
ok( $content =~ m/silly with "quotes"/gms, "found entry with quotes" );

append_if_no_such_line( $filename, line => "#include /etc/sudoers.d/*.conf" );

my @content = split( /\n/, cat($filename) );
ok( $content[-1] ne "#include /etc/sudoers.d/*.conf",
  "last entry is not #include ..." );

append_if_no_such_line( $filename, 'KEY="VAL"' );
$content = cat($filename);
ok( $content =~ m/KEY="VAL"/gms, "found KEY=VAL" );

append_if_no_such_line(
  $filename,
  "change",
  qr{change},
  on_change => sub {
    $changed = 0;
  }
);

ok( $changed == 1, "nothing was changed in the file" );

append_if_no_such_line(
  $filename,
  "change",
  on_change => sub {
    $changed = 0;
  }
);

ok( $changed == 1, "nothing was changed in the file without regexp" );

$content = cat($filename);
ok( $content !~ m/foobar/gms, "not found foobar" );

append_if_no_such_line( $filename, line => "foobar", );
$content = cat($filename);
ok( $content =~ m/foobar/gms, "found foobar" );

append_if_no_such_line(
  $filename,
  line   => "bazzada",
  regexp => qr{^foobar},
);
$content = cat($filename);

ok( $content !~ m/bazzada/gms, "found bazzada" );

append_if_no_such_line(
  $filename,
  line   => "tacktack",
  regexp => qr{blah blah}ms,
);
$content = cat($filename);

ok( $content !~ m/tacktack/gms, "not found tacktack" );

append_if_no_such_line(
  $filename,
  line   => "nothing there",
  regexp => [ qr{blah blah}ms, qr{tzuhgjbn}ms ],
);
$content = cat($filename);

ok( $content !~ m/nothing there/gms, "not found nothing there" );

append_if_no_such_line(
  $filename,
  line   => "this is there",
  regexp => [ qr{qaywsx}ms, qr{tzuhgjbn}ms ],
);
$content = cat($filename);

ok( $content =~ m/this is there/gms, "found this is there" );

append_if_no_such_line(
  $filename,
  line   => "bazzada",
  regexp => qr{^bazzada},
);
$content = cat($filename);
ok( $content =~ m/bazzada/gms, "found bazzada (2)" );

file "file with space-$$.txt", content => "file with space\n";

ok( is_file("file with space-$$.txt"), "file with space exists" );

$c = "";
$c = cat "file with space-$$.txt";
ok( $c =~ m/file with space/m, "found content of file with space" );

Rex::Commands::Fs::unlink($filename);
Rex::Commands::Fs::unlink("file with space-$$.txt");

ok( !is_file($filename),                "test.txt removed" );
ok( !is_file("file with space-$$.txt"), "file with space removed" );

$filename = "$tmp_dir/test-sed-$$.txt";

file $filename,
  content =>
  "this is a sed test file\nthese are just some lines\n0505\n0606\n0707\n'foo'\n/etc/passwd\n\"baz\"\n{klonk}\nfoo bar\n\\.-~'[a-z]\$ foo {1} /with/some/slashes \%\&()?\n|.-\\~'[a-z]\$ bar {2} /with/more/slashes \%\&()?\n";

sed qr/fo{2} bar/, "baz bar", $filename;
$content = cat $filename;
ok( $content =~ m/baz bar/, "sed replaced foo bar" );

sed qr/^\\\.\-\~'\[a\-z\]\$ foo \{1\} \/with\/some\/slashes/, "got replaced",
  $filename;
$content = cat $filename;
ok( $content =~ m/got replaced/, "sed replaced strange chars" );

sed qr/^\|\.\-\\\~'\[a\-z\]\$ BAR \{2\} \/with\/more\/slashes/i,
  "got another replace", $filename;
$content = cat $filename;
ok( $content =~ m/got another replace/, "sed replaced strange chars" );

my @lines = split( /\n/, $content );
ok(
  $lines[-1] =~ m/^got another replace/,
  "last line was successfully replaced"
);
ok( $lines[-2] =~ m/^got replaced/,
  "second last line was successfully replaced" );
ok( $lines[-4] =~ m/^\{klonk\}/, "fourth last line untouched" );

sed qr{0606}, "6666", $filename;
$content = cat $filename;
ok( $content =~ m/6666/, "sed replaced 0606" );

sed qr{'foo'}, "'bar'", $filename;
$content = cat $filename;
ok( $content =~ m/'bar'/, "sed replaced 'foo'" );

sed qr{/etc/passwd}, "/etc/shadow", $filename;
$content = cat $filename;
ok( $content =~ m/\/etc\/shadow/, "sed replaced /etc/passwd" );

sed qr{"baz"}, '"boooooz"', $filename;
$content = cat $filename;
ok( $content =~ m/"boooooz"/, "sed replaced baz" );

sed qr/{klonk}/, '{plonk}', $filename;
$content = cat $filename;
ok( $content =~ m/{plonk}/, "sed replaced {klonk}" );

sed qr/{klonk}/, '{plonk}', $filename;
$content = cat $filename;
ok( $content =~ m/{plonk}/, "sed replaced {klonk}" );

unlink $filename;

file "$tmp_dir/multiline-$$.txt", content => "this is\na test.\n";
sed qr/is\sa test/msi, "no one\nknows!", "$tmp_dir/multiline-$$.txt",
  multiline => 1;
$content = cat "$tmp_dir/multiline-$$.txt";
is( $content, "this no one\nknows!.\n", "multiline replacement" );

unlink "$tmp_dir/multiline-$$.txt";

file "$tmp_dir/test.d-$$", ensure => "directory";

ok( -d "$tmp_dir/test.d-$$", "created directory with file()" );
rmdir "$tmp_dir/test.d-$$";
