#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands;

use strict;
use warnings;

use Data::Dumper;

require Exporter;

use vars qw(@EXPORT $current_desc);
use base qw(Exporter);

@EXPORT = qw(task desc group user password);

sub task {
   my($class, $file, @tmp) = caller;
   my $task_name = shift;
   if($class ne "main") {
      $task_name = $class . ":" . $task_name;
   }

   $task_name =~ s/^Rex:://;
   $task_name =~ s/::/:/g;

   if($current_desc) {
      push(@_, $current_desc);
      $current_desc = "";
   }

   Rex::Task->create_task($task_name, @_);
}

sub desc {
   $current_desc = shift;
}

sub group {
   Rex::Group->create_group(@_);
}

sub user {
   Rex::Config->set_user(@_);
}

sub password {
   Rex::Config->set_password(@_);
}

1;
