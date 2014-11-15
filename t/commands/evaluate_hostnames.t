#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Rex::Commands;

my %tests = (
    'server1.domain.com'       => [ qw/server1.domain.com/ ],
    'server[9..10].domain.com' => [qw/
        server9.domain.com
        server10.domain.com
    /],
    'server[6..10/2].domain.com' => [qw/
        server6.domain.com
        server8.domain.com
        server10.domain.com
    /],
    'server[6,8,10].domain.com' => [qw/
        server6.domain.com
        server8.domain.com
        server10.domain.com
    /],
    'server[4..6,8,10..12].domain.com' => [qw/
        server4.domain.com
        server5.domain.com
        server6.domain.com
        server8.domain.com
        server10.domain.com
        server11.domain.com
        server12.domain.com
    /],
    'server[4..6,8,10..16/2].domain.com' => [qw/
        server4.domain.com
        server5.domain.com
        server6.domain.com
        server8.domain.com
        server10.domain.com
        server12.domain.com
        server14.domain.com
        server16.domain.com
    /],
    'server[1..3,2..4].domain.com' => [qw/
        server1.domain.com
        server2.domain.com
        server3.domain.com
        server2.domain.com
        server3.domain.com
        server4.domain.com
    /],
);

for my $test ( sort keys %tests ) {
    my @result = Rex::Commands::evaluate_hostname( $test );
    is_deeply \@result, $tests{$test}, $test;
}

done_testing();
