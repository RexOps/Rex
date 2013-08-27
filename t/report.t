use strict;
use warnings;

use Test::More tests => 5;
use_ok 'Rex::Report';
use_ok 'Rex::Report::Base';
use_ok 'Rex::Report::YAML';
use_ok 'Rex::Commands';
Rex::Commands->import;

$::QUIET = 1; $::QUIET = 1;

my $report = Rex::Report->create;
ok(ref($report) eq "Rex::Report::Base", "created report class");
