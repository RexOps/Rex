use strict;
use warnings;

use Test::More tests => 10;
use YAML;
use_ok 'Rex';
use_ok 'Rex::Report';
use_ok 'Rex::Report::Base';
use_ok 'Rex::Report::YAML';
use_ok 'Rex::Commands';
use_ok 'Rex::Commands::File';
use_ok 'Rex::Commands::Fs';
Rex::Commands->import;

$::QUIET = 1; $::QUIET = 1;

my $report = Rex::Report->create;
ok(ref($report) eq "Rex::Report::Base", "created report class");

mkdir "tmp";

Rex::Report->destroy;

report(-on => "YAML");
set(report_path => "tmp/report");

task("test", sub {
   file("test_report.txt", content => "this is a test");
});

Rex::TaskList->create()->get_task("test")->run("<local>");

use Data::Dumper;
my @files = list_files("tmp/report/_local_");
my $content = eval { local(@ARGV, $/) = ("tmp/report/_local_/$files[0]"); <>; };
my $ref = Load($content);

ok($ref->[0]->{changed} == 1, "a new file was created.");

# need to wait a bit
sleep 2;

Rex::TaskList->create()->get_task("test")->run("<local>");
@files = list_files("tmp/report/_local_/");
$content = eval { local(@ARGV, $/) = ("tmp/report/_local_/$files[1]"); <>; };
$ref = Load($content);

ok($ref->[0]->{changed} == 0, "the file was not changed");



unlink "test_report.txt";

rmdir("tmp");

