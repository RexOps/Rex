package t::tasks::cowbefore;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;

desc "bring in the cattle";
task "roundup" => sub { return 1 };

before ALL => sub { return 'yo' };
1;
