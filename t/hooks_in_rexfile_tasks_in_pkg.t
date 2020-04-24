package Rex::CLI;

BEGIN {
  use Test::More tests => 8;
  use lib 't/lib';
  use t::tasks::alien;
  use File::Temp;
  use Rex::Commands;
  use Rex::RunList;
  use Rex::Shared::Var;
  share
    qw( $before_task_start_all $before_task_start $before_all $before $after $after_all $after_task_finished $after_task_finished_all);
}

$::QUIET = 1;

timeout 1;

before_task_start ALL => sub { $before_task_start_all += 1; };
before_task_start 't:tasks:alien:negotiate' => sub { $before_task_start += 1 };
before ALL                                  => sub { $before_all        += 1 };
before 't:tasks:alien:negotiate'            => sub { $before            += 1 };

after 't:tasks:alien:negotiate' => sub { $after     += 1 };
after ALL                       => sub { $after_all += 1 };
after_task_finished 't:tasks:alien:negotiate' =>
  sub { $after_task_finished += 1 };
after_task_finished ALL => sub { $after_task_finished_all += 1 };

@ARGV = qw(t:tasks:alien:negotiate);
my $run_list = Rex::RunList->instance;
$run_list->parse_opts(@ARGV);

$run_list->run_tasks;

is $before_task_start_all, 1, 'before_task_start ALL hook';
is $before_task_start,     1, 'before_task_start hook';
is $before_all,            1, 'before ALL hook';
is $before,                1, 'before hook';

is $after,                   1, 'after hook';
is $after_all,               1, 'after ALL hook';
is $after_task_finished,     1, 'after_task_finished hook';
is $after_task_finished_all, 1, 'after_task_finished ALL hook';
