use Test::More tests => 4;

use Rex::Commands::Run;

$::QUIET = 1;

SKIP: {
  skip 'Do not run tests on Windows', 4 if $^O =~ m/^MSWin/mxsi;

  my $path = '/tmp/inexistent path with spaces/';
  my $tail = 'hello';
  my $parm = 'hello Rex';
  my $s    = run "$path$tail";
  like( $s, qr{$path}ms,
    "The inexistent path or file is not reported correctly" );

  mkdir $path;
  symlink( '/bin/echo', "$path$tail" );
  $s = run "$path$tail $parm";
  like( $s, qr{$parm}sm, qq($path$tail $parm didn't work) );

  $s = run "$path$tail /$parm";
  like( $s, qr{$path}sm, "/slash on parms and the comand didn't fail?" );

  $s = run qq("$path$tail" /$parm);
  like( $s, qr{/$parm}sm, "Quoted command failed" );

  unlink $path . $tail;
  rmdir $path;

}
