
use Test::More tests => 6;

use strict;
use warnings;
use 5.010;
use autodie qw(:all);
use English qw($OSNAME -no_match_vars);
use File::Temp;

use Rex::Commands::Run;

$::QUIET = 1;

my $win = $OSNAME =~ m/^MSWin/mxsi;
my $quote = q{"};
my $space = q{ };
my $empty = q{};

sub command {
  my ( $path, $exe, @parm ) = @_;
  return qq{$path/$exe } . join $empty, @parm;
}

sub relative {
  return qq{./$_[0]};
}

my $path    = File::Temp->newdir( 'path with spaces XXXX', DIR => q{./} );
my $tail    = 'hello';
my $parm    = 'Rex is wonderfull';
my $testcmd = '/bin/echo';
my $s       = run command relative($path), $tail, $parm;

#on windows if the path not exists not apears on the output
my $not_exists = ( $win && $s !~ /(?-x:$path)/smx ) ? $s : $path;

like( $s, qr{(?-x:$not_exists)}smx, q{inexistent command gives an error} );

my $cmd = relative qq{$path/$tail};

if ($win) {

  #On windows we create hello.bat contaning echo %1
  $cmd .= q{.bat};
  open my $hello, q{>}, $cmd;
  print {$hello} "echo %*\n";
  close $hello;
}
else {
  #hello is a sybolic link to echo
  if ( !-X $testcmd ) {
    substr $testcmd, 0, 0, q{/usr};
  }
  symlink $testcmd, $cmd;
}

my $result = qr{^(?-x:$parm)}smx;

$s = run command( relative($path), $tail, $parm );
like( $s, $result, q{path with spaces parse ok} );

$s = run command( relative($path), $tail, $parm, q{ /extra} );
like( $s, $result, 'an " /"  on the parmeters parse ok' );

$s = run command( $quote . relative($path), $tail . $quote, $parm );
like( $s, $result, 'Quoted commands ok' );

#Partialy quoted paths don't work on windows
#$s = run command( relative(qq{"$path"}), $tail, $parm );
#like( $s, $result, 'Partially quoted' );

my $mpath = join $empty, relative($path), q{/}, $tail;

if ($win) {
  $mpath =~ s{/}{\\}gsmx;
  $s = run join $space, $mpath, $parm;
  like( $s, $result, "($mpath $parm) windows path ok" );
}
else {
  $mpath =~ s{(\s)}{\\$1}gsmx;
  $s = run join $space, $mpath, $parm;
  like( $s, $result, "($mpath $parm) back slash escapes ok" );
}

like( run( command $path->{REALNAME}, $tail, $parm ), $result, 'fullpath ok' );
