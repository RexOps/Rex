use strict;
use warnings;

use Cwd 'getcwd';
my $cwd = getcwd;
use File::Spec;
use File::Temp;

use Test::More tests => 61;

use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Gather;
use Rex::Commands::Run;

Rex::Config->set( foo => "bar" );

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

ok( $c, "cat" );
like( $c, qr/blah/, "file with content (1)" );
like( $c, qr/bar/,  "file with content (2)" );

Rex::Commands::Fs::unlink($filename);

is( is_file($filename), undef, "file removed" );

file(
  $filename,
  content => "blah blah\nbaaazzzz",
  mode    => 777
);

my %stats = Rex::Commands::Fs::stat($filename);
if ( is_windows() && $^O ne "cygwin" ) {
  is( $stats{mode}, "0666", "windows without chmod" );
}
else {
  is( $stats{mode}, "0777", "fs chmod ok" );
}

my $changed = 0;
my $content = cat($filename);
unlike( $content, qr/change/ms, "found change" );

append_if_no_such_line(
  $filename,
  "change",
  qr{change},
  on_change => sub {
    $changed = 1;
  }
);

$content = cat($filename);
like( $content, qr/change/ms, "found change" );

is( $changed, 1, "something was changed in the file" );

append_if_no_such_line(
  $filename,
  line   => "dream-breaker",
  regexp => qr{^dream-breaker$}
);

$content = cat($filename);
like( $content, qr/dream\-breaker/ms, "found dream-breaker" );

append_if_no_such_line(
  $filename,
  line   => "#include /etc/sudoers.d/*.conf",
  regexp => qr{^#include /etc/sudoers.d/\*.conf$},
);

$content = cat($filename);
like( $content, qr{#include /etc/sudoers\.d/\*\.conf}ms,
  "found sudoers entry" );

append_if_no_such_line( $filename, line => 'silly with "quotes"' );

$content = cat($filename);
like( $content, qr/silly with "quotes"/ms, "found entry with quotes" );

append_if_no_such_line( $filename, line => "#include /etc/sudoers.d/*.conf" );

my @content = split( /\n/, cat($filename) );
isnt(
  $content[-1],
  "#include /etc/sudoers.d/*.conf",
  "last entry is not #include ..."
);

append_if_no_such_line( $filename, 'KEY="VAL"' );
$content = cat($filename);
like( $content, qr/KEY="VAL"/ms, "found KEY=VAL" );

my $no_change = 0;
append_if_no_such_line(
  $filename,
  "change",
  qr{change},
  on_change => sub {
    $changed = 0;
  },
  on_no_change => sub {
    $no_change = 1;
  }
);

is( $changed,   1, "nothing was changed in the file" );
is( $no_change, 1, "no change handler triggered" );

append_if_no_such_line(
  $filename,
  "change",
  on_change => sub {
    $changed = 0;
  },
  on_no_change => sub {
    $no_change = 2;
  }
);

is( $changed,   1, "nothing was changed in the file without regexp" );
is( $no_change, 2, "no change handler triggered" );

$content = cat($filename);
unlike( $content, qr/foobar/ms, "not found foobar" );

append_if_no_such_line( $filename, line => "foobar", );
$content = cat($filename);
like( $content, qr/foobar/ms, "found foobar" );

append_if_no_such_line(
  $filename,
  line   => "bazzada",
  regexp => qr{^foobar},
);
$content = cat($filename);

unlike( $content, qr/bazzada/ms, "not found bazzada" );

append_if_no_such_line(
  $filename,
  line   => "tacktack",
  regexp => qr{blah blah}ms,
);
$content = cat($filename);

unlike( $content, qr/tacktack/ms, "not found tacktack" );

append_if_no_such_line(
  $filename,
  line   => "nothing there",
  regexp => [ qr{blah blah}ms, qr{tzuhgjbn}ms ],
);
$content = cat($filename);

unlike( $content, qr/nothing there/ms, "not found nothing there" );

append_if_no_such_line(
  $filename,
  line   => "this is there",
  regexp => [ qr{qaywsx}ms, qr{tzuhgjbn}ms ],
);
$content = cat($filename);

like( $content, qr/this is there/ms, "found this is there" );

append_if_no_such_line(
  $filename,
  line   => "bazzada",
  regexp => qr{^bazzada},
);
$content = cat($filename);
like( $content, qr/bazzada/ms, "found bazzada (2)" );

append_or_amend_line(
  $filename,
  line   => 'silly more "quotes"',
  regexp => qr{^silly with "quotes"},
);
$content = cat($filename);
like( $content, qr/silly more "quotes"/m, "found silly more quotes" );
unlike(
  $content,
  qr/silly with "quotes"/m,
  "silly with quotes no longer exists"
);

append_or_amend_line(
  $filename,
  line   => "dream-maker",
  regexp => qr{^dream\-},
);
$content = cat($filename);
like( $content, qr/^dream\-maker$/m, "found dream-maker" );
unlike( $content, qr/^dream\-breaker$/m, "dream-breaker no longer exists" );

append_or_amend_line(
  $filename,
  line   => "dream2-maker",
  regexp => qr{^dream2\-},
);
$content = cat($filename);
like( $content, qr/^dream2\-maker$/m, "found dream2-maker" );
like( $content, qr/^dream\-maker$/m,  "dream-maker still exists" );

append_or_amend_line(
  $filename,
  line   => "dream3-maker",
  regexp => qr{^dream2\-},
);
$content = cat($filename);
like( $content, qr/^dream3\-maker$/m, "found dream3-maker" );
unlike( $content, qr/^dream2\-maker$/m, "dream2-maker no longer exists" );
like( $content, qr/^dream\-maker$/m, "dream-maker still exists" );
unlike( $content, qr/^$/m, "no extra blank lines inserted" );

file "file with space-$$.txt", content => "file with space\n";

is( is_file("file with space-$$.txt"), 1, "file with space exists" );

$c = "";
$c = cat "file with space-$$.txt";
like( $c, qr/file with space/m, "found content of file with space" );

Rex::Commands::Fs::unlink("file with space-$$.txt");
is( is_file("file with space-$$.txt"), undef, "file with space removed" );

file "file_with_\@-$$.txt", content => "file with at sign\n";

is( is_file("file_with_\@-$$.txt"), 1, "file with at sign exists" );

$c = "";
$c = cat "file_with_\@-$$.txt";
like( $c, qr/file with at sign/m, "found content of file with at sign" );

Rex::Commands::Fs::unlink("file_with_\@-$$.txt");
is( is_file("file_with_\@-$$.txt"), undef, "file with at sign removed" );

Rex::Commands::Fs::unlink($filename);
is( is_file($filename), undef, "test.txt removed" );

$filename = "$tmp_dir/test-sed-$$.txt";

file $filename,
  content =>
  "this is a sed test file\nthese are just some lines\n0505\n0606\n0707\n'foo'\n/etc/passwd\n\"baz\"\n{klonk}\nfoo bar\n\\.-~'[a-z]\$ foo {1} /with/some/slashes \%\&()?\n|.-\\~'[a-z]\$ bar {2} /with/more/slashes \%\&()?\n";

sed qr/fo{2} bar/, "baz bar", $filename;
$content = cat $filename;
like( $content, qr/baz bar/, "sed replaced foo bar" );

sed qr/^\\\.\-\~'\[a\-z\]\$ foo \{1\} \/with\/some\/slashes/, "got replaced",
  $filename;
$content = cat $filename;
like( $content, qr/got replaced/, "sed replaced strange chars" );

sed qr/^\|\.\-\\\~'\[a\-z\]\$ BAR \{2\} \/with\/more\/slashes/i,
  "got another replace", $filename;
$content = cat $filename;
like( $content, qr/got another replace/, "sed replaced strange chars" );

my @lines = split( /\n/, $content );
like(
  $lines[-1],
  qr/^got another replace/,
  "last line was successfully replaced"
);
like(
  $lines[-2],
  qr/^got replaced/,
  "second last line was successfully replaced"
);
like( $lines[-4], qr/^\{klonk\}/, "fourth last line untouched" );

sed qr{0606}, "6666", $filename;
$content = cat $filename;
like( $content, qr/6666/, "sed replaced 0606" );

sed qr{'foo'}, "'bar'", $filename;
$content = cat $filename;
like( $content, qr/'bar'/, "sed replaced 'foo'" );

sed qr{/etc/passwd}, "/etc/shadow", $filename;
$content = cat $filename;
like( $content, qr/\/etc\/shadow/, "sed replaced /etc/passwd" );

sed qr{"baz"}, '"boooooz"', $filename;
$content = cat $filename;
like( $content, qr/"boooooz"/, "sed replaced baz" );

sed qr/{klonk}/, '{plonk}', $filename;
$content = cat $filename;
like( $content, qr/{plonk}/, "sed replaced {klonk}" );

sed qr/{klonk}/, '{plonk}', $filename;
$content = cat $filename;
like( $content, qr/{plonk}/, "sed replaced {klonk}" );

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

$changed = 0;
file "$tmp_dir/test.d-$$",
  ensure    => "directory",
  on_change => sub {
  $changed = 1;
  };

ok( $changed,                "on_change hook with directory" );
ok( -d "$tmp_dir/test.d-$$", "created directory with file()" );
rmdir "$tmp_dir/test.d-$$";

$content = 'Hello this is <%= $::foo %>';
is(
  template( \$content, __no_sys_info__ => 1 ),
  "Hello this is bar",
  "get keys from Rex::Config"
);

is(
  template( \$content, { foo => "baz", __no_sys_info__ => 1 } ),
  "Hello this is baz",
  "overwrite keys from Rex::Config"
);

subtest 'get temp file name' => sub {
  my $testfile          = "temp-$$";
  my $testfile_absolute = File::Spec->catfile( $tmp_dir, $testfile );

  my %temp_file_for = (
    $testfile          => ".rex.tmp.$testfile",
    $testfile_absolute => File::Spec->catfile( $tmp_dir, ".rex.tmp.$testfile" ),
  );

  for my $filename ( sort keys %temp_file_for ) {
    my $tempfile = Rex::Commands::File::get_tmp_file_name($filename);
    is( $tempfile, $temp_file_for{$filename}, 'temp file name matches' );
  }
};

TODO: {
  local $TODO = 'on_change hook is triggered unconditionally on Windows'
    if ( $^O =~ /MSWin/ );

  subtest 'on_change hook with source option' => sub {
    my $testfile1 = File::Temp->new()->filename;
    my $testfile2 = File::Temp->new()->filename;

    my $changed;

    file $testfile1, content => 'change', on_change => sub { $changed += 1 };

    is( $changed, 1, 'on_change when creating a new file with content' );

    file $testfile2, source => $testfile1, on_change => sub { $changed += 1 };

    is( $changed, 2, 'on_change when creating a new file with source' );

    file $testfile2, source => $testfile1, on_change => sub { $changed += 1 };

    is( $changed, 2, 'on_change when uploading the same file again' );
  };
}
