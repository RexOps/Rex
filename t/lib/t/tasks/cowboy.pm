package t::tasks::cowboy;

use v5.12.5;

use Rex -base;

desc "bring in the cattle";
task "roundup" => sub { return 1 };

include 't::tasks::alien';

1;
