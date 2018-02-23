package t::tasks::chicken;
use Rex -base;

desc "cross the road";
task "cross_road" => sub { return "make a break for it!" };

before_task_start "cross_road"   => sub { return "look left" };
before_task_start "cross_road"   => sub { return "look right" };
after_task_finished "cross_road" => sub { return "got to the other side" };
after_task_finished "cross_road" => sub { return "celebrate!" };
1;
