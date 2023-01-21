#!/usr/bin/env perl

use 5.010001;
use strict;
use warnings;
use autodie;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 16;

use File::Spec;
use File::Temp;
use Rex::CLI;
use Rex::Commands::File;
use Sub::Override;
use Test::Output;

## no critic (RegularExpressions);
## no critic (DuplicateLiteral);

$Rex::Logger::format = '%l - %s';

my $testdir      = File::Spec->join( 't', 'rexfiles' );
my $rex_cli_path = $INC{'Rex/CLI.pm'};
my $empty        = q();

my ( $exit_was_called, $expected );

my $override =
  Sub::Override->new( 'Rex::CLI::exit' => sub { $exit_was_called = 1 } );

#
# enable this to debug!
#
$::QUIET = 1;

#$Rex::Logger::no_color = 1;
my $logfile = File::Temp->new->filename;
Rex::Config->set_log_filename($logfile);

# NOW TEST

# No Rexfile warning (via Rex::Logger)
my $rexfile = File::Spec->join( $testdir, 'no_Rexfile' );

_setup_test();

Rex::CLI::load_rexfile($rexfile);

is( cat($logfile), $expected->{log}, 'No Rexfile warning (via logger)' );

# Valid Rexfile
$rexfile = File::Spec->join( $testdir, 'Rexfile_noerror' );

_setup_test();

output_like { Rex::CLI::load_rexfile($rexfile); } qr/^$/, qr/^$/,
  'No stdout/stderr messages on valid Rexfile';

is( cat($logfile), $expected->{log},
  'No warnings on valid Rexfile (via logger)' );

# Rexfile with warnings
$rexfile = File::Spec->join( $testdir, 'Rexfile_warnings' );

_setup_test();

output_like { Rex::CLI::load_rexfile($rexfile); } qr/^$/, qr/^$/,
  'No stdout/stderr messages on Rexfile with warnings';

ok( !$exit_was_called, 'sub load_rexfile() not exit' );

is( cat($logfile), $expected->{log}, 'Warnings present (via logger)' );

# Rexfile with fatal errors
$rexfile = File::Spec->join( $testdir, 'Rexfile_fatal' );

_setup_test();

output_like { Rex::CLI::load_rexfile($rexfile); } qr/^$/, qr/^$/,
  'No stdout/stderr messages on Rexfile with errors';

ok( $exit_was_called, 'sub load_rexfile() aborts' );

is( cat($logfile), $expected->{log}, 'Errors present (via logger)' );

# Now print messages to STDERR/STDOUT
# Valid Rexfile
$rexfile = File::Spec->join( $testdir, 'Rexfile_noerror_print' );

_setup_test();

output_like { Rex::CLI::load_rexfile($rexfile); } qr/^This is STDOUT message$/,
  qr/^This is STDERR message$/,
  'Correct stdout/stderr messages printed from valid Rexfile';

is( cat($logfile), $expected->{log},
  'No warnings via logger on valid Rexfile that print messages' );

# Rexfile with warnings
$rexfile = File::Spec->join( $testdir, 'Rexfile_warnings_print' );

_setup_test();

output_like { Rex::CLI::load_rexfile($rexfile); } qr/^This is STDOUT message$/,
  qr/^This is STDERR message$/,
  'Correct stdout/stderr messages printed from Rexfile with warnings';

is( cat($logfile), $expected->{log}, 'Code warnings exist via logger' );

# Rexfile with fatal errors
$rexfile = File::Spec->join( $testdir, 'Rexfile_fatal_print' );

_setup_test();

output_like { Rex::CLI::load_rexfile($rexfile); } qr/^$/, qr/^$/,
  'No stdout/stderr messages printed from Rexfile that has errors';

ok( $exit_was_called, 'sub load_rexfile() aborts' );

is( cat($logfile), $expected->{log}, 'Fatal errors exist via logger' );

sub _setup_test {
  Rex::TaskList->create->clear_tasks();

  $exit_was_called = undef;

  $expected->{log} = -r "$rexfile.log" ? cat("$rexfile.log") : $empty;
  $expected->{log} =~ s{%REX_CLI_PATH%}{$rex_cli_path}msx;

  # reset log
  open my $fh, '>', $logfile;
  close $fh;

  # reset require
  delete $INC{'__Rexfile__.pm'};

  return;
}
