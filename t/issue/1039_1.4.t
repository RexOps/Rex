use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 3;

use Rex::Commands;
use Rex::Commands::Task;
use Rex::Args;
use Rex::RunList;
use Rex::Config;

# no fork, so the test inside the task works
Rex::TaskList->create()->set_in_transaction(1);

Rex::Config->set_task_chaining_cmdline_args(1);

task test1 => sub {
  my $args = shift;
  is( $args->{'foo'}, undef, 'NOT found key foo inside task.' );
};

@ARGV = ( 'test', '--foo=bar' );
my %args = Rex::Args->get;

is( $args{'foo'},  'bar', "NOT found key foo" );
is( $args{'test'}, 1,     "found task name with value 1" );

do_task 'test1';
