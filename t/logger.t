#!/usr/bin/env perl

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Test::More tests => 9;
use Test::Warnings;

use Rex::Helper::Path;

no warnings 'once';
$::QUIET = 1;

my $logfile = Rex::Helper::Path::get_tmp_file();

# log to a file
ok( !-e $logfile, 'Logfile does not exist' );
Rex::Config->set_log_filename($logfile);

$Rex::Logger::format = '%l - %s';

{
  # only info messages are logged
  Rex::Logger::debug('debug1');
  Rex::Logger::info('info1');

  my $logcheck = qq~INFO - info1\n~;

  my $content = _get_log();
  is( $content, $logcheck, "only info messages are logged" );
}

{
  $Rex::Logger::silent = 1;

  Rex::Logger::debug('debug1');
  Rex::Logger::info('info1');

  my $logcheck = qq~INFO - info1\n~;

  my $content = _get_log();
  is( $content, $logcheck, "no logging added while silent" );
}

{
  $Rex::Logger::silent = 0;
  $Rex::Logger::debug  = 1;

  Rex::Logger::debug('debug1');
  Rex::Logger::info('info2');

  my $logcheck = qq~INFO - info1
DEBUG - debug1
INFO - info2
~;

  my $content = _get_log();
  is( $content, $logcheck, "all messages are logged" );
}

{
  $Rex::Logger::format = '%D - %l - %s';

  my $date_regex = '\d{4}-\d{2}-\d{2} (?:\d+:){2}\d+';

  Rex::Logger::debug('debug2');
  Rex::Logger::info('info3');

  my $logcheck = qq~INFO - info1
DEBUG - debug1
INFO - info2
$date_regex - DEBUG - debug2
$date_regex - INFO - info3
~;

  my $content = _get_log();
  like( $content, qr/$logcheck/, "all messages are logged - with date" );
}

Rex::Logger->shutdown;
ok( -e $logfile, 'Logfile still available' );
unlink $logfile;
ok( !-e $logfile, 'Logfile unlinked' );

my $masq_s = Rex::Logger::masq( "This is a password: %s", "pass" );
is( $masq_s, "This is a password: **********", "Log-Masquerading" );

sub _get_log {
  local $/;

  open my $fh, '<', $logfile or die $!;
  my $loglines = <$fh>;
  close $fh;

  return $loglines;
}
