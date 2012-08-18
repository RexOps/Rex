#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Executor::Default;
   
use strict;
use warnings;

use Rex::Logger;
use Rex::Output;
use Data::Dumper;

use Rex::Interface::Executor::Base;
use base qw(Rex::Interface::Executor::Base);

require Rex::Args;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub exec {
   my ($self, $opts) = @_;

   $opts ||= { Rex::Args->get };

   my $task = $self->{task};

   Rex::Logger::debug("Executing " . $task->name);

   my $ret;
   eval {
      my $code = $task->code;
      $ret = &$code($opts);
   };

   if($@) {
      if(Rex::Output->get) {
         Rex::Output->get->add($task->name, error => 1, msg => $@);
      }
      else {
         die($@);
      }
   }
   else {
      if(Rex::Output->get) {
         Rex::Output->get->add($task->name);
      }
   }

   return $ret;
}

1;
