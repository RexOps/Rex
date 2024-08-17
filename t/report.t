#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 4;
use Test::Warnings;
use YAML;

use Rex::Commands;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Report::YAML;

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
isa_ok( $report, "Rex::Report::Base", "created report class" );

mkdir "tmp";

Rex::Report->destroy;

report( -on => "YAML" );
set( report_path => "tmp/report" );
my $report_num = 1;
Rex::Report::YAML->set_report_name(
  sub {
    return $report_num;
  }
);

task(
  "test",
  sub {
    file( "test_report.txt", content => "this is a test" );
  }
);

Rex::TaskList->create()->get_task("test")->run("<local>");

my @files = list_files("tmp/report/_local_");
my $content =
  eval { local ( @ARGV, $/ ) = ("tmp/report/_local_/$files[0]"); <>; };

my $ref = Load($content);

is( $ref->{'file[test_report.txt]'}->{changed}, 1, "a new file was created." );

$report_num += 1;

Rex::TaskList->create()->get_task("test")->run("<local>");
@files = sort { $a =~ s/\.yml//; $b =~ s/\.yml//; $a <=> $b }
  list_files("tmp/report/_local_/");
$content =
  eval { local ( @ARGV, $/ ) = ("tmp/report/_local_/$files[1].yml"); <>; };

$ref = Load($content);

is( $ref->{'file[test_report.txt]'}->{changed}, 0, "the file was not changed" );

unlink "test_report.txt";

if ( $^O =~ m/^MSWin/ ) {
  system("rd /Q /S tmp\\report");
}
else {
  system("rm -rf tmp/report");
}
