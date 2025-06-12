package t::tasks::alien;

use v5.14.4;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex -base;

desc "negotiate with the aliens";
task "negotiate" => sub { return 1 };

1;
