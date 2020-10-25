#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Batch;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::TaskList;

use vars qw(%batchs);

sub create_batch {
  my $class      = shift;
  my $batch_name = shift;
  my $batch_desc = pop;
  my @task_names = @_;
  my $task_list  = Rex::TaskList->create;

  for my $task_name (@task_names) {
    die "ERROR: no task: $task_name"
      unless $task_list->is_task($task_name);
  }

  $batchs{$batch_name} = {
    desc       => $batch_desc,
    task_names => \@task_names
  };
}

sub get_batch {
  my $class      = shift;
  my $batch_name = shift;

  return @{ $batchs{$batch_name}->{'task_names'} };
}

sub get_desc {
  my $class      = shift;
  my $batch_name = shift;

  return $batchs{$batch_name}->{'desc'};
}

sub get_batchs {
  my $class = shift;
  my @a     = sort { $a cmp $b } keys %batchs;
}

sub is_batch {
  my $class      = shift;
  my $batch_name = shift;

  if ( defined $batchs{$batch_name} ) { return 1; }
  return 0;
}

1;
