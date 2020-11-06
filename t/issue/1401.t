use 5.010;

use Test::More tests => 7;

use Rex::Commands::Run;

$::QUIET = 1;

my $win = $^O =~ m/^MSWin/mxsi;

my $path = './inexistent path with spaces/';
ok( !-e $path, qq{"$path" not exists} );

my $tail      = 'hello';
my $parm      = 'Rex is wonderfull';
my $s         = run qq{$path$tail $parm};
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
  #hello is a sybolic link to echo
  my $echo = '/bin/echo';
  if ( !-X $echo ) {
    substr $echo, 0, 0, q{/usr};
  }
  symlink $echo, qq{$path$tail};
}

$s = run qq{$path$tail $parm};
like( $s, qr{$parm}sm, qq{"$path$tail $parm"  ok} );

$s = run qq{$path$tail /$parm};
like( $s, qr{$parm}sm, '/slash on parms ok' );

$s = run qq{"$path$tail" $parm};
like( $s, qr{$parm}sm, "Quoted commands ok" );
my $mpath = $path;

if ($win) {
  $mpath =~ s{/}{\\}gsmx;
  $s = run qq{$mpath$tail $parm};
  like( $s, qr{$parm}sm, "($mpath$tail $parm) windows path ok" );
}
else {
  $mpath =~ s{(\s)}{\\$1}gsmx;
  $s = run qq{$mpath$tail $parm};
  like( $s, qr{$parm}sm, "($mpath$tail $parm) back slash escapes ok" );
}

unlink "$path$tail" . ( $win ? q{.bat} : q{} );
rmdir $path;

