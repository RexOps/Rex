use Test::More tests => 7;

use Rex::Commands::Run;

$::QUIET = 1;

my $win = $^O =~ m/^MSWin/mxsi;

my $path = './inexistent path with spaces/';
ok( !-e $path, qq("$path" not exists) );

my $tail      = 'hello';
my $parm      = 'Rex is wonderfull';
my $s         = run "$path$tail $parm";
my $notExists = ( $win and !-e $path ) ? $s : qq{$path$tail};

like( $s, qr{$notExists}sm,
  qq{windows dont return "$path/$tail" on the message} );

ok( mkdir($path), qq{creating "$path"} );

if ($win) {

  #On windows we create hello.bat contaning echo %1
  open my $hello, '>', qq{$path$tail.bat};
  print $hello "echo %*\n";
  close $hello;
}
else {
  #hello is a sybolic link to /usr/bin/echo
  symlink "/usr/bin/echo", qq{$path$tail};
}

$s = run "$path$tail $parm";
like( $s, qr{$parm}sm, qq{$path$tail $parm didn't work} );

$s = run "$path$tail /$parm";
like( $s, qr{$parm}sm, "/slash on parms and the comand didn't fail?" );

$s = run qq("$path$tail" $parm);
like( $s, qr{$parm}sm, "Quoted commands pass" );
my $mpath = $path;

if ($win) {
  $mpath =~ s{/}{\\}gsmx;
  $s = run qq($mpath$tail $parm);
  like( $s, qr{$parm}sm, "($mpath$tail $parm) windows format pass" );
}
else {
  $mpath =~ s{(\s)}{\\$1}gsmx;
  $s = run qq($mpath$tail $parm);
  like( $s, qr{$parm}sm, "($mpath$tail $parm) scaped espaces pass" );
}

unlink "$path$tail" . ( $win ? q{.bat} : q{} );
rmdir $path;

