use strict;
use warnings;
use lib 't/lib';
use t::Helper qw/test_rex /;
use Test::More;

test_rex
    args      => '-f aasdf97987',
    exit_code => 1;

test_rex
    args      => 'bogus_task_name',
    exit_code => 1;

test_rex
    args      => '-e "say run \"pwd\""',
    exit_code => 0,
    stderr    => qr/INFO - All tasks successful on all hosts/;

done_testing;
