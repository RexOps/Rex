package t::tasks::alien;

use v5.12.5;
use warnings;

use Rex -base;

desc "negotiate with the aliens";
task "negotiate" => sub { return 1 };

1;
