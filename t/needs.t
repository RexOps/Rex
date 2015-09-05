package MyTest;

use strict;
use warnings;

$::QUIET = 1;

use Rex::Commands;

task "test1", sub {
    open( my $fh, ">", "test1.txt" );
    close($fh);
};

task "test2", sub {
    open( my $fh, ">", "test2.txt" );
    close($fh);
};

1;

package main;

use Test::More;

use Rex::Commands;

task "test", sub {
    needs MyTest;

    if ( -f "test1.txt" && -f "test2.txt" ) {
      unlink("test1.txt");
      unlink("test2.txt");

      return 1;
    }

    is( 1, -1 );
};

task "test2", sub {
    needs MyTest "test2";

    if ( -f "test2.txt" ) {
      unlink("test2.txt");
      return 1;
    }

    is( 1, -1 );

};

task "test3", sub {
    needs("test4");

    if ( -f "test4.txt" ) {
      unlink("test4.txt");
      return 1;
    }

    is( 1, -1 );
};

task "test4", sub {
    open( my $fh, ">", "test4.txt" );
    close($fh);
};

my $task_list = Rex::TaskList->create;
my $run_list = Rex::RunList->instance;
$run_list->parse_opts(qw/test test2 test3/);
  
for my $task ($run_list->tasks) {
    ok $task_list->run($task), $task->name;
    $run_list->increment_current_index;
}

#my $task  = $run_list->next_task;
#my $task2 = $task_list->get_task("test2");
#my $task3 = $task_list->get_task("test3");
#
#ok $task_list->run($task),  "testing needs";
##ok $task_list->run($task2), "testing needs";
##ok $task_list->run($task3), "testing needs - local namespace";

done_testing;

1;
