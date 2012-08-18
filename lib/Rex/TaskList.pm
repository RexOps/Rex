#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::TaskList;
   
use strict;
use warnings;

use Rex::Config;
use Rex::Logger;
use Rex::Interface::Executor;
use Rex::Fork::Manager;

use vars qw(%tasks);

# will be set from Rex::Transaction::transaction()
our $task_list = {};

sub create {
   my ($class) = @_;

   # create only one object
   if(ref($task_list) =~ m/^Rex::TaskList::/) {
      Rex::Logger::debug("Returning existing distribution class of type: " . ref($task_list));
      return $task_list;
   }

   my $type = Rex::Config->get_distributor;
   Rex::Logger::debug("Creating new distribution class of type: $type");

   my $class_name = "Rex::TaskList::$type";

   eval "use $class_name";
   if($@) {
      die("TaskList module not found.");
   }

   $task_list = $class_name->new;

   Rex::Logger::debug("new distribution class of type " . ref($task_list) . " created.");

   return $task_list;
}

