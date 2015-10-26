use strict;
use warnings;

use Test::More;

use Rex::Args;

@ARGV = qw(
  -h -g test1 -g test2 -T -dv -u user -p pass -t 5 foo --name=thename --num=5
);

Rex::Args->parse_rex_opts;

my %opts   = Rex::Args->getopts;
my $groups = $opts{g};

is_deeply( $groups, [qw/test1 test2/], "Got array for groups" );

ok( exists $opts{h} && $opts{h}, "single parameter" );
ok( exists $opts{T} && $opts{T}, "single parameter (2)" );
ok( exists $opts{d} && $opts{d}, "single parameter (3) (multiple)" );
ok( exists $opts{v} && $opts{v}, "single parameter (4) (multiple)" );
ok(
  exists $opts{u} && $opts{u} eq "user",
  "parameter with option (1) / string"
);
ok(
  exists $opts{p} && $opts{p} eq "pass",
  "parameter with option (2) / string"
);
ok( exists $opts{t} && $opts{t} == 5, "parameter with option (3) / integer" );

is( $ARGV[0], "foo", "got the taskname" );

done_testing;
