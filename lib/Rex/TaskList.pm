#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::TaskList;

use strict;
use warnings;

# VERSION

use Data::Dumper;
use Rex::Config;
use Rex::Logger;
use Rex::Interface::Executor;

use vars qw(%tasks);

# will be set from Rex::Transaction::transaction()
our $task_list = {};

sub create {
  my ($class) = @_;

  # create only one object
  if ( ref($task_list) =~ m/^Rex::TaskList::/ ) {
    Rex::Logger::debug(
      "Returning existing distribution class of type: " . ref($task_list) );
    return $task_list;
  }

  my $type = Rex::Config->get_distributor;
  Rex::Logger::debug("Creating new distribution class of type: $type");

  my $class_name = "Rex::TaskList::$type";

  eval "use $class_name";
  if ($@) {
    die("TaskList module not found: $@");
  }

  $task_list = $class_name->new;

  Rex::Logger::debug(
    "new distribution class of type " . ref($task_list) . " created." );

  return $task_list;
}

sub run {
  my ( $class, $task_name ) = @_;
  my $task = $class->create()->get_task($task_name);
  $_->($task) for @{ $task->{before_task_start} };
  $class->create->run($task);
  $_->($task) for @{ $task->{after_task_finished} };
}
