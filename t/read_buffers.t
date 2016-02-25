use strict;
use warnings;

use Test::More tests => 2;
use Rex::Interface::Exec;

Rex::Config->set_no_tty(1);
my $exec = Rex::Interface::Exec->create;

my $command =
  q{perl -e "my \$count = 2_000_000; while ( \$count-- ) { if ( \$count % 2) { print STDERR 'x'} else { print STDOUT 'x'} }"};

alarm 5;

$SIG{ALRM} = sub { BAIL_OUT 'Reading from buffer timed out'; };

my ( $out, $err ) = $exec->exec($command);

is length($out), 1_000_000, 'STDOUT length';
is length($err), 1_000_000, 'STDERR length'
