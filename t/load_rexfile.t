#!/usr/bin/env perl
use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More;
use Test::Output;
use File::Temp;
use File::Spec;

use Rex::CLI;
## no critic (ProhibitPostfixControls, WhileDiamondDefaultAssignment);
## no critic (ProhibitPunctuationVars, ProhibitPackageVars);
## no critic (RequireCheckedSyscalls, RequireCheckedClose);
## no critic (RegularExpressions);
## no critic (Carping, ProhibitNoWarnings, DuplicateLiteral);

#diag 'create some rexfiles to test...';
my $fh      = undef;
my $testdir = File::Temp->newdir( 'rextest.XXXX', TMPDIR => 1, CLEANUP => 1 );
while (<DATA>) {
  last if /^__END__$/;
  if (/^@@ *(\S+)$/) {

    #diag "prepare file $1";
    close $fh if $fh;
    open $fh, '>', File::Spec->catfile( $testdir, $1 ) or die $!;
    next;
  }
  print {$fh} $_ if $fh;
}
close $fh if $fh;

our $exit_was_called = undef;

# we must disable Rex::CLI::exit() sub imported from Rex::Commands
no warnings 'redefine';
local *Rex::CLI::exit = sub { $exit_was_called = 1 };
use warnings 'redefine';

#
# enable this to debug!
#
$::QUIET = 1;

#$Rex::Logger::no_color = 1;
my $logfile = File::Spec->catfile( $testdir, 'log' );
Rex::Config->set_log_filename($logfile);

# NOW TEST

# No Rexfile warning (via Rex::Logger)
Rex::CLI::load_rexfile( File::Spec->catfile( $testdir, 'no_Rexfile' ) );
my $content = _get_log();
like( $content, qr/WARN - No Rexfile found/,
  'No Rexfile warning (via logger)' );

# Valid Rexfile
_reset_test();
output_like {
  Rex::CLI::load_rexfile( File::Spec->catfile( $testdir, 'Rexfile_noerror' ) );
}
qr/^$/, qr/^$/, 'No stdout/stderr messages on valid Rexfile';
$content = _get_log();
is( $content, q{}, 'No warnings on valid Rexfile (via logger)' );

# Rexfile with warnings
_reset_test();
output_like {
  Rex::CLI::load_rexfile( File::Spec->catfile( $testdir, 'Rexfile_warnings' ) );
}
qr/^$/, qr/^$/, 'No stdout/stderr messages on Rexfile with warnings';
$content = _get_log();
ok( !$exit_was_called, 'sub load_rexfile() not exit' );
like(
  $content,
  qr/WARN - You have some code warnings/,
  'Code warnings via logger'
);
like( $content, qr/This is warning/, 'warn() warning via logger' );
like(
  $content,
  qr/Use of uninitialized value \$undef/,
  'perl warning via logger'
);
unlike(
  $content,
  qr#at /loader/0x#,
  'loader prefix is filtered in warnings report'
);

# Rexfile with fatal errors
_reset_test();
output_like {
  Rex::CLI::load_rexfile( File::Spec->catfile( $testdir, 'Rexfile_fatal' ) );
}
qr/^$/, qr/^$/, 'No stdout/stderr messages on Rexfile with errors';
$content = _get_log();
ok( $exit_was_called, 'sub load_rexfile() aborts' );
like( $content, qr/ERROR - Compile time errors/, 'Fatal errors via logger' );
like( $content, qr/syntax error at/, 'syntax error is fatal error via logger' );
unlike(
  $content,
  qr#at /loader/0x#,
  'loader prefix is filtered in errors report'
);

# Now print messages to STDERR/STDOUT
# Valid Rexfile
_reset_test();
output_like {
  Rex::CLI::load_rexfile(
    File::Spec->catfile( $testdir, 'Rexfile_noerror_print' ) );
}
qr/^This is STDOUT message$/, qr/^This is STDERR message$/,
  'Correct stdout/stderr messages printed from valid Rexfile';
$content = _get_log();
is( $content, q{},
  'No warnings via logger on valid Rexfile that print messages' );

# Rexfile with warnings
_reset_test();
output_like {
  Rex::CLI::load_rexfile(
    File::Spec->catfile( $testdir, 'Rexfile_warnings_print' ) );
}
qr/^This is STDOUT message$/, qr/^This is STDERR message$/,
  'Correct stdout/stderr messages printed from Rexfile with warnings';
$content = _get_log();
like(
  $content,
  qr/WARN - You have some code warnings/,
  'Code warnings exist via logger'
);

# Rexfile with fatal errors
_reset_test();
output_like {
  Rex::CLI::load_rexfile(
    File::Spec->catfile( $testdir, 'Rexfile_fatal_print' ) );
}
qr/^$/, qr/^$/,
  'No stdout/stderr messages printed from Rexfile that has errors';
$content = _get_log();
ok( $exit_was_called, 'sub load_rexfile() aborts' );
like(
  $content,
  qr/ERROR - Compile time errors/,
  'Fatal errors exist via logger'
);

done_testing;

# from logger.t
sub _get_log {
  ## no critic (LocalVars)
  local $/;

  open my $fh, '<', $logfile or die $!;
  my $loglines = <$fh>;
  close $fh;

  return $loglines;
}

sub _reset_test {
  $exit_was_called = undef;

  # reset log
  open my $fh, '>', $logfile or die $!;
  close $fh;

  # reset require
  delete $INC{'__Rexfile__.pm'};

  return;
}

__DATA__
@@ Rexfile_noerror
use Rex;
user 'testuser';
task test => sub { say "test1" };

@@ Rexfile_warnings
use Rex;
use warnings;
warn 'This is warning';
my $undef; my $warn = 'warn'.$undef;
user 'testuser';
task test => sub { say "test2" };

@@ Rexfile_fatal
use Rex;
aaaabbbbcccc
task test => sub { say "test3" };

@@ Rexfile_noerror_print
use Rex;
user 'testuser';
print STDERR 'This is STDERR message';
print STDOUT 'This is STDOUT message';
task test2 => sub { say "test4" };

@@ Rexfile_warnings_print
use Rex;
use warnings;
warn 'This is warning';
my $undef; my $warn = 'warn'.$undef;
print STDERR 'This is STDERR message';
print STDOUT 'This is STDOUT message';
user 'testuser';
task test2 => sub { say "test5" };

@@ Rexfile_fatal_print
use Rex;
print STDERR 'This is STDERR message';
print STDOUT 'This is STDOUT message';
aaaabbbbcccc
print STDERR 'This is STDERR message';
print STDOUT 'This is STDOUT message';
task test2 => sub { say "test6" };

