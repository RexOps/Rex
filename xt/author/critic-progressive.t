use strict;
use warnings;
use Test::More;

plan skip_all => 'these tests are for testing by the author'
  unless $ENV{AUTHOR_TESTING};

use Test::Perl::Critic::Progressive qw(progressive_critic_ok);

progressive_critic_ok();
