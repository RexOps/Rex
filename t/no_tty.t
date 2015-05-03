use Test::More tests => 3;

use Rex::Commands::Run;
use Rex::Config;

$::QUIET = 1;

SKIP: {
  skip 'don\'t know how to test this right on windows', 3 if $^O =~ m/^MSWin/;

  Rex::Config->set_no_tty(0);
  my $s = run("ls -l /jllkjlkj");
  like( $s, qr/No such file/, "with tty" );

  Rex::Config->set_no_tty(1);
  $s = run("ls -l /jllkjlkj");
  unlike( $s, qr/No such file/, "with no tty" );

  Rex::Config->set_no_tty(0);
  $s = run("ls -l /jllkjlkj");
  like( $s, qr/No such file/, "again with tty" );
}

