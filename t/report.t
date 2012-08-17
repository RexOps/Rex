use strict;
use warnings;

use Test::More tests => 6;
use_ok 'Rex::Report';
use_ok 'Rex::Report::Base';
use_ok 'Rex::Commands';
Rex::Commands->import;

my $report = Rex::Report->create;
ok(ref($report) eq "Rex::Report::Base", "created report class");
ok($report->report("abcd") == 4, "reported 4 bytes");
ok(report("xyz") == 3, "reported 3 bytes");
