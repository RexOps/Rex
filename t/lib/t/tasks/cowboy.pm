package t::tasks::cowboy;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;

desc "bring in the cattle";
task "roundup" => sub { return 1 };

include 't::tasks::alien';

1;
