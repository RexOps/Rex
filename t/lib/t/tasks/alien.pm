use 5.12.5;

package t::tasks::alien;
use Rex -base;

desc "negotiate with the aliens";
task "negotiate" => sub { return 1 };

1;
