#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::CommandLine;

use strict;
use warnings;
use Rex -base;

require Rex::Args;
use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub command {
   my ($self, $command, $do_connect, @args) = @_;
no strict 'refs';

   if($do_connect) {
      Rex::connect(
         server      => $ENV{REX_REMOTE_HOST},
         user        => $ENV{REX_REMOTE_USER},
         password    => $ENV{REX_REMOTE_PASSWORD},
         private_key => $ENV{REX_REMOTE_PRIVATE_KEY},
         public_key  => $ENV{REX_REMOTE_PUBLIC_KEY},
      );

      return &$command(@args);
   }
   else {
      return LOCAL {
         return &$command(@args);
      };
   }
}

sub call {
   my ($self, $command, %option) = @_;

   $Rex::Args::REMOVE_TASK_OPTIONS = 1;

   Rex::Args->import(
      L => {},
   ); 

   my %opts = Rex::Args->getopts;
   #$::QUIET = 1;

   if(exists $option{join_argv}) {
      @ARGV = join($option{join_argv}, @ARGV);
   }

   my $do_connect = 1;

   if(exists $opts{L} || (exists $option{local_execution} && $option{local_execution} == 1)) {
      $do_connect = 0;
   }

   my %task_args = Rex::Args->get;
   my %task_args_e;
   my $mod_code = $option{mod_args} || sub {};

   for my $key (keys %task_args) {
      my $val = $mod_code->($key, $task_args{$key});
      if($val) {
         $task_args_e{$key} = $val;
      }
   }

   return $self->command($command, $do_connect, @ARGV, %task_args_e);
}

1;
