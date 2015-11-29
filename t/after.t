use strict;
use warnings;

use Test::More tests => 1;
use File::Temp;
use Rex::Commands;

#$Rex::Logger::debug = 1;
$::QUIET = 1;

my $fh = File::Temp->new;

timeout 1;

task  foo => "asdfsadfasdf" => sub { return "yo" };
after foo => sub { unlink $fh->filename; };

Rex::TaskList->run("foo");
ok ! -e $fh->filename, "after hook runs even when the ssh connection fails";

