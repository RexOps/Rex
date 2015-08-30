package t::tasks::cowboy;
use Rex -base;

desc "bring in the cattle";
task "roundup" => sub { return 1 };

include 't::tasks::alien';

1;
