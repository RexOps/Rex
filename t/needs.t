use Test::More;
use Rex::Commands;

{

  package MyTest;
  use strict;
  use warnings;
  use Rex::Commands;

  $::QUIET = 1;

  task "test1", sub {
    open( my $fh, ">", "test1.txt" );
    close($fh);
  };

  task "test2", sub {
    open( my $fh, ">", "test2.txt" );
    close($fh);
  };

  1;
}

{

  package Nested::Module;

  use strict;
  use warnings;

  use Rex::Commands;

  task "test", sub {
    open( my $fh, ">", "test.txt" );
    close($fh);
  };
}

{

  package Rex::Module;

  use strict;
  use warnings;

  use Rex::Commands;

  task "test", sub {
    open( my $fh, ">", "test.txt" );
    close($fh);
  };
}

task "test", sub {
  needs MyTest;

  if ( -f "test1.txt" && -f "test2.txt" ) {
    unlink("test1.txt");
    unlink("test2.txt");
    return 1;
  }

  die;
};

task "test2", sub {
  needs MyTest "test2";

  if ( -f "test2.txt" ) {
    unlink("test2.txt");
    return 1;
  }

  die;
};

task "test3", sub {
  needs("test4");

  if ( -f "test4.txt" ) {
    unlink("test4.txt");
    return 1;
  }

  die;
};

task "test4", sub {
  open( my $fh, ">", "test4.txt" );
  close($fh);
};

task "test5", sub {
  needs Nested::Module "test";

  if ( -f "test.txt" ) {
    unlink("test.txt");
    return 1;
  }

  die;
};

task "test6", sub {
  needs Rex::Module "test";

  if ( -f "test.txt" ) {
    unlink("test.txt");
    return 1;
  }

  die;
};

my $task_list = Rex::TaskList->create;
my $run_list  = Rex::RunList->instance;
$run_list->parse_opts(qw/test test2 test3 test5 test6/);

for my $task ( $run_list->tasks ) {
  $task_list->run($task);
  my @summary = $task_list->get_summary;
  is_deeply $summary[-1]->{exit_code}, 0, $task->name;
  $run_list->increment_current_index;
}

done_testing;
