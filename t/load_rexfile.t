#!/usr/bin/env perl

use v5.12.5;
use warnings;
use autodie;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Warnings;

use English qw(-no_match_vars);
use File::Spec;
use File::Temp;
use Rex::CLI;
use Rex::Commands::File;
use Sub::Override;
use Test::Output;

use constant FIRST_PERL_VERSION_WITH_EXTRA_ERROR_MESSAGE => v5.37.9;

$Rex::Logger::format   = '%l - %s';
$Rex::Logger::no_color = 1;

my $testdir      = File::Spec->join( 't', 'rexfiles' );
my $rex_cli_path = $INC{'Rex/CLI.pm'};
my $empty        = q();

my ( $dh, $exit_was_called, $expected );

my $override =
  Sub::Override->new( 'Rex::CLI::exit' => sub { $exit_was_called = 1 } );

my $logfile = File::Temp->new->filename;
Rex::Config->set_log_filename($logfile);

opendir $dh, $testdir;
my @rexfiles = grep { !/[.]/msx } readdir $dh;
closedir $dh;

push @rexfiles, 'no_Rexfile';

plan tests => scalar @rexfiles + 1;

for my $rexfile (@rexfiles) {
  subtest "Testing with $rexfile" => sub {
    $rexfile = File::Spec->join( $testdir, $rexfile );

    _setup_test($rexfile);

    output_is { Rex::CLI::load_rexfile($rexfile); } $expected->{stdout},
      $expected->{stderr}, 'Expected console output';

    is( $exit_was_called, $expected->{exit}, 'Expected exit status' );
    is( cat($logfile),    $expected->{log},  'Expected log content' );
  };
}

sub _setup_test {
  my $rexfile = shift;

  Rex::TaskList->create->clear_tasks();

  $exit_was_called = 0;

  $expected->{exit} = $rexfile =~ qr{fatal}ms ? 1 : 0;

  for my $extension (qw(log stdout stderr)) {
    my $file            = "$rexfile.$extension";
    my $default_content = $extension eq 'stderr' ? $expected->{log} : $empty;

    if ( -r $file ) {
      if ( $PERL_VERSION lt FIRST_PERL_VERSION_WITH_EXTRA_ERROR_MESSAGE
        && $expected->{exit} == 1 )
      {
        my @output_lines = split qr{^}msx, cat($file);
        pop @output_lines;
        $expected->{$extension} = join $empty, @output_lines;
      }
      else {
        $expected->{$extension} = cat($file);
      }
    }
    else {
      $expected->{$extension} = $default_content;
    }

    $expected->{$extension} =~ s{%REXFILE_PATH%}{$rexfile}gmsx;
  }

  # reset log
  open my $fh, '>', $logfile;
  close $fh;

  # reset require
  delete $INC{'__Rexfile__.pm'};

  return;
}
