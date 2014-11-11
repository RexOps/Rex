#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Rex::Commands;

my %tests = (
    'server1.domain.com'       => [ qw/server1.domain.com/ ],
    'server[9..10].domain.com' => [qw/
        server09.domain.com
        server10.domain.com
    /],
    'server[6..10/2].domain.com' => [qw/
        server06.domain.com
        server08.domain.com
        server10.domain.com
    /],
    'server[6,8,10].domain.com' => [qw/
        server6.domain.com
        server8.domain.com
        server10.domain.com
    /],
);

for my $test ( sort keys %tests ) {
    my @result = Rex::Commands::evaluate_hostname( $test );
    is_deeply \@result, $tests{$test}, $test;
}

done_testing();
