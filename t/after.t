use strict;
use warnings;

use Test::More tests => 1;
use File::Temp;
use Rex::Commands;

#$Rex::Logger::debug = 1;
$::QUIET = 1;

my $fh = File::Temp->new( UNLINK => 0 );

# this is for windows. If we don't close the filehandle
# windows will lock the file so it can't be deleted.
my $filename = $fh->filename;
undef $fh;

timeout 1;

task foo => "asdfsadfasdf" => sub { return "yo" };
after foo => sub { unlink $filename; };

Rex::TaskList->run("foo");

ok !-e $filename, "after hook runs even when the ssh connection fails";

