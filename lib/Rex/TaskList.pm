#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::TaskList;

use warnings;

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
    die("TaskList module not found.");
  }

  $task_list = $class_name->new;

  Rex::Logger::debug(
    "new distribution class of type " . ref($task_list) . " created." );

  return $task_list;
}

sub run {
  my ( $class, $task_name ) = @_;
  my $task_object = $class->create()->get_task($task_name);

  for my $code ( @{ $task_object->{before_task_start} } ) {
    $code->($task_object);
  }

  $class->create()->run($task_name);

  for my $code ( @{ $task_object->{after_task_finished} } ) {
    $code->($task_object);
  }
}
