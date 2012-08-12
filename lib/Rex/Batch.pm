#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Batch;

use strict;
use warnings;

use Rex::Logger;
use Rex::TaskList;

use vars qw(%batchs);

sub create_batch {
   my $class = shift;
   my $batch_name = shift;
   my $batch_desc = pop;
   my @tasks = @_;

   $batchs{$batch_name} = {
      desc => $batch_desc,
      tasks => \@tasks
   };
}

sub get_batch {
   my $class = shift;
   my $batch_name = shift;

   return @{$batchs{$batch_name}->{'tasks'}};
}

sub get_desc {
   my $class = shift;
   my $batch_name = shift;

   return $batchs{$batch_name}->{'desc'};
}

sub get_batchs {
   my $class = shift;
   my @a = sort { $a cmp $b } keys %batchs;
}

sub is_batch {
   my $class = shift;
   my $batch_name = shift;

   if(defined $batchs{$batch_name}) { return 1; }
   return 0;
}

sub run {
   my $class = shift;
   my $batch = shift;

   my @tasks = $class->get_batch($batch);
   for my $t (@tasks) {
      if(Rex::TaskList->create()->is_task($t)) {
         Rex::TaskList->create()->run($t);
      } else {
         print STDERR "ERROR: no task: $t\n";
         die;
      }
   }
}

1;
