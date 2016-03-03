use strict;
use warnings;

use Test::More;

if ( $^O =~ m/^MSWin/i ) {
  plan tests => 1;
}
else {
  plan tests => 2;
}

use Rex::Interface::Exec;

my $tty = $^O =~ m/^MSWin/i ? 0 : 1;
Rex::Config->set_no_tty($tty);

my $exec = Rex::Interface::Exec->create;

my $command =
  ( $^O =~ m/^MSWin/i && Rex::is_local() )
  ? qq{perl -e "my \$count = 500_000; while ( \$count-- ) { if ( \$count % 2) { print STDERR 'x'} else { print STDOUT 'x'} }"}
  : qq{perl -e 'my \$count = 500_000; while ( \$count-- ) { if ( \$count % 2) { print STDERR "x"} else { print STDOUT "x"} }'};

alarm 30;

$SIG{ALRM} = sub { BAIL_OUT 'Reading from buffer timed out'; };

my ( $out, $err ) = $exec->exec($command);

alarm 0;

if ( $^O =~ m/^MSWin/i ) {
  is length($out), 500_000, 'output length on Windows';
}
else {
  is length($out), 250_000, 'STDOUT length';
  is length($err), 250_000, 'STDERR length';
}
