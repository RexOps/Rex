package t::tasks::cowbefore;
use Rex -base;

desc "bring in the cattle";
task "roundup" => sub { return 1 };

before ALL => sub { return 'yo' };
1;
