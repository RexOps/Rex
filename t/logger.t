#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok 'Rex';
use_ok 'Rex::Logger';
use_ok 'Rex::Config';
use_ok 'Rex::Helper::Path';

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

done_testing();

sub _get_log {
  local $/;

  open my $fh, '<', $logfile or die $!;
  my $loglines = <$fh>;
  close $fh;

  return $loglines;
}
