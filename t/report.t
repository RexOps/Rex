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

{
  no warnings 'once';
  $::QUIET = 1;
}

if ( $^O =~ m/^MSWin/ ) {
  system("rd /Q /S tmp\\report");
}
else {
  system("rm -rf tmp/report");
}

my $report = Rex::Report->create;
ok( ref($report) eq "Rex::Report::Base", "created report class" );

mkdir "tmp";

Rex::Report->destroy;

report( -on => "YAML" );
set( report_path => "tmp/report" );

task(
  "test",
  sub {
    file( "test_report.txt", content => "this is a test" );
  }
);

Rex::TaskList->create()->get_task("test")->run("<local>");

use Data::Dumper;
my @files = list_files("tmp/report/_local_");
my $content =
  eval { local ( @ARGV, $/ ) = ("tmp/report/_local_/$files[0]"); <>; };

my $ref = Load($content);

ok( $ref->{'file[test_report.txt]'}->{changed} == 1,
  "a new file was created." );

# need to wait a bit
sleep 2;

Rex::TaskList->create()->get_task("test")->run("<local>");
@files = sort { $a =~ s/\.yml//; $b =~ s/\.yml//; $a <=> $b }
  list_files("tmp/report/_local_/");
$content =
  eval { local ( @ARGV, $/ ) = ("tmp/report/_local_/$files[1].yml"); <>; };

$ref = Load($content);

ok( $ref->{'file[test_report.txt]'}->{changed} == 0,
  "the file was not changed" );

unlink "test_report.txt";

if ( $^O =~ m/^MSWin/ ) {
  system("rd /Q /S tmp\\report");
}
else {
  system("rm -rf tmp/report");
}
