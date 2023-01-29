package t::tasks::cowbefore;

use v5.12.5;

use Rex -base;

desc "bring in the cattle";
task "roundup" => sub { return 1 };

before ALL => sub { return 'yo' };
1;
