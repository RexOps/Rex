use strict;
use warnings;

use Test::More tests => 13;
use Data::Dumper;

use_ok 'Rex::Args';

push(@ARGV, qw(-h -T -dv -u user -p pass -t 5 foo --name=thename --num=5));

Rex::Args->import(
   C => {},
   c => {},
   q => {},
   Q => {},
   F => {},
   T => {},
   h => {},
   v => {},
   d => {},
   s => {},
   S => { type => "string" },
   E => { type => "string" },
   o => { type => "string" },
   f => { type => "string" },
   M => { type => "string" },
   b => { type => "string" },
   e => { type => "string" },
   H => { type => "string" },
   u => { type => "string" },
   p => { type => "string" },
   P => { type => "string" },
   K => { type => "string" },
   G => { type => "string" },
   t => { type => "integer" },
);

my %opts = Rex::Args->getopts;

ok(exists $opts{h} && $opts{h}, "single parameter");
ok(exists $opts{T} && $opts{T}, "single parameter (2)");
ok(exists $opts{d} && $opts{d}, "single parameter (3) (multiple)");
ok(exists $opts{v} && $opts{v}, "single parameter (4) (multiple)");
ok(exists $opts{u} && $opts{u} eq "user", "parameter with option (1) / string");
ok(exists $opts{p} && $opts{p} eq "pass", "parameter with option (2) / string");
ok(exists $opts{t} && $opts{t} == 5, "parameter with option (3) / integer");

ok($ARGV[0] eq "foo", "got the taskname");

my %params = Rex::Args->get;

ok($ARGV[1] eq "--name=thename", "got the whole parameter (1)");
ok($ARGV[2] eq "--num=5", "got the whole parameter (2)");

ok(exists $params{name} && $params{name} eq "thename", "got task parameter (1)");
ok(exists $params{num} && $params{num} == 5, "got task parameter (2)");


