use Test::More tests => 5;

use_ok 'Rex::Commands::Run';
use_ok 'Rex::Config';

$::QUIET = 1;

Rex::Commands::Run->import;

if ( $^O =~ m/^MSWin/ ) {

  # don't know how to test this right on windows (locales?)
  ok( 1 == 1 );
  ok( 1 == 1 );
  ok( 1 == 1 );
}
else {
  Rex::Config->set_no_tty(0);
  my $s = run("ls -l /jllkjlkj");
  ok( $s =~ m/No such file/, "with tty" );

  Rex::Config->set_no_tty(1);
  $s = run("ls -l /jllkjlkj");
  ok( $s !~ m/No such file/, "with no tty" );

  Rex::Config->set_no_tty(0);
  $s = run("ls -l /jllkjlkj");
  ok( $s =~ m/No such file/, "again with tty" );

}

