use strict;
use warnings;
use 5.010;
use autodie;
use English qw($OSNAME -no_match_vars);

use Test::More tests => 7;

use Rex::Commands::Run;

$::QUIET = 1;

my $win = $OSNAME =~ m/^MSWin/mxsi;

my $path = './inexistent path with spaces/';
ok( !-e $path, qq{"$path" not exists} );

my $tail       = 'hello';
my $parm       = 'Rex is wonderfull';
my $t_cmd      = qq{$path$tail $parm};
my $s          = run $t_cmd;
my $not_exists = ( $win && !-e $path ) ? $s : qq{$path$tail};

like( $s, qr{(?-x:$not_exists)}smx,
  qq{windows dont return "$path$tail" on the message} );

ok( mkdir($path), qq{creating "$path"} );
my $cmd = $path . $tail;

if ($win) {

  #On windows we create hello.bat contaning echo %1
  $cmd .= q{bat};
  open my $hello, '>', $cmd;
  print {$hello} "echo %*\n";
  close $hello;
}
else {
  #hello is a sybolic link to echo
  my $echo = '/bin/echo';
  if ( !-X $echo ) {
    substr $echo, 0, 0, q{/usr};
  }
  symlink $echo, $cmd;
}

my $result = qr{(?-x:$parm)}smx;

$s = run $t_cmd;
like( $s, $result, qq{"$t_cmd"  ok} );

$s = run qq{$path$tail /$parm};
like( $s, $result, '/slash on parms ok' );

$s = run qq{"$path$tail" $parm};
like( $s, $result, 'Quoted commands ok' );
my $mpath = $path;

if ($win) {
  $mpath =~ s{/}{\\}gsmx;
  $s = run qq{$mpath$tail $parm};
  like( $s, $result, "($mpath$tail $parm) windows path ok" );
}
else {
  $mpath =~ s{(\s)}{\\$1}gsmx;
  $mpath .= $tail;
  $s = run qq{$mpath $parm};
  like( $s, $result, "($mpath $parm) back slash escapes ok" );
}

unlink $cmd;
rmdir $path;
