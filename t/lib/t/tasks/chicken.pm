package t::tasks::chicken;
use Rex -base;

desc "cross the road";
task "cross_road" => sub { return "make a break for it!" };

before_task_start "cross_road"   => sub { return "checked for traffic" };
after_task_finished "cross_road" => sub { return "got to the other side" };
1;
