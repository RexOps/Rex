use Test::More tests => 4;

use Rex::Commands::Run;

$::QUIET = 1;

SKIP: {
  skip 'Do not run tests on Windows', 4 if $^O =~ m/^MSWin/i;

  my $path = '/tmp/inexistent path with spaces/';
  my $tail = 'hello';
  my $parm = 'hello Rex';
  my $s = run "$path$tail";
  like( $s, qr/$path/, "The inexistent path or file is not reported correctly" );
  mkdir $path;
  symlink( '/bin/echo',"$path$tail" ) or die $!;
  $s = run "$path$tail $parm";
  like( $s, qr/^$parm/, "`$path$tail $parm` didn't work" );
  $s = run "$path$tail /$parm";
  like( $s,qr/$path/,"/slash on parms and the comand didn't fail?");
  $s = run "\"$path$tail\" /$parm";
  like($s,qr|^/$parm|,"Quotend command failed");
  unlink $path.$tail;
  rmdir $path;

}
