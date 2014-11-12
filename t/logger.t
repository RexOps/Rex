#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Basename;

use_ok 'Rex';
use_ok 'Rex::Logger';
use_ok 'Rex::Config';

my $logfile = sprintf "%s/rex.test.log",
    dirname(__FILE__) || '.';

# log to a file
ok( !-e $logfile );
Rex::Config->set_log_filename( $logfile );

$Rex::Logger::format = '%l - %s';

{
  # only info messages are logged
  Rex::Logger::debug( 'debug1' );
  Rex::Logger::info( 'info1' );

  my $logcheck = qq~INFO - info1\n~;

  my $content = do { local( @ARGV, $/ ) = $logfile; <> };
  is( $content, $logcheck, "only info messages are logged" );
}

{
  $Rex::Logger::silent = 1;

  Rex::Logger::debug( 'debug1' );
  Rex::Logger::info( 'info1' );

  my $logcheck = qq~INFO - info1\n~;

  my $content = do { local( @ARGV, $/ ) = $logfile; <> };
  is( $content, $logcheck, "no logging added while silen" );
}

{
  $Rex::Logger::silent = 0;
  $Rex::Logger::debug = 1;

  Rex::Logger::debug( 'debug1' );
  Rex::Logger::info( 'info2' );

  my $logcheck = qq~INFO - info1
DEBUG - debug1
INFO - info2
~;

  my $content = do { local( @ARGV, $/ ) = $logfile; <> };
  is( $content, $logcheck, "all messages are logged" );
}

{
  $Rex::Logger::format = '%D - %l - %s';

  my $date = sprintf '\d{4}-\d{2}-\d{2} (?:\d+:){2}\d+'; 

  Rex::Logger::debug( 'debug2' );
  Rex::Logger::info( 'info3' );

  my $logcheck = qq~INFO - info1
DEBUG - debug1
INFO - info2
$date - DEBUG - debug2
$date - INFO - info3
~;

  my $content = do { local( @ARGV, $/ ) = $logfile; <> };
  like( $content, qr/$logcheck/, "all messages are logged - with date" );
}

Rex::Logger->shutdown;
ok( -e $logfile, 'Logfile still available' );
unlink $logfile;
ok( !-e $logfile );


done_testing();
