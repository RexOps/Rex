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
use Rex::Task;
use Rex::Logger;

use vars qw(@EXPORT $current_desc);
use base qw(Exporter);

use feature qw(say);

@EXPORT = qw(task desc group 
            user password public_key private_key pass_auth
            get_random do_task batch timeout parallelism
            exit
            evaluate_hostname
            logging
            needs
            say
          );

sub task {
   my($class, $file, @tmp) = caller;
   my $task_name = shift;
   my $task_name_save = $task_name;

   if($class ne "main") {
      $task_name = $class . ":" . $task_name;
   }

   $task_name =~ s/^Rex:://;
   $task_name =~ s/::/:/g;

   if($current_desc) {
      push(@_, $current_desc);
      $current_desc = "";
   }
   else {
      push(@_, "");
   }

   no strict 'refs';
   push (@{"${class}::tasks"}, { name => $task_name_save, code => $_[-2] } );
   use strict;

   Rex::Task->create_task($task_name, @_);
}

sub desc {
   $current_desc = shift;
}

sub group {
   Rex::Group->create_group(@_);
}

sub batch {
   if($current_desc) {
      push(@_, $current_desc);
      $current_desc = "";
   }
   else {
      push(@_, "");
   }

   Rex::Batch->create_batch(@_);
}

sub user {
   Rex::Config->set_user(@_);
}

sub password {
   Rex::Config->set_password(@_);
}

sub timeout {
   Rex::Config->set_timeout(@_);
}

sub get_random {
	my $count = shift;
	my @chars = @_;
	
	srand();
	my $ret = "";
	for(0..$count) {
		$ret .= $chars[int(rand(scalar(@chars)-1))];
	}
	
	return $ret;
}

sub evaluate_hostname {
   my $str = shift;

   my ($start, $from, $to, $dummy, $step, $end) = $str =~ m/^([\w-]+)\[(\d+)..(\d+)(\/(\d+))?\]([\w\.-]+)?$/;

   unless($start) {
      return $str;
   }

   $end  ||= '';
   $step ||= 1;

   my $strict_length = 0;
   if( length $from == length $to ) {
      $strict_length = length $to;
   }

   my @ret = ();
   for(; $from <= $to; $from += $step) {
         my $format = "%0".$strict_length."i";
         push @ret, $start . sprintf($format, $from) . $end;
   }

   return @ret;
}

sub do_task {
   my $task = shift;

   return Rex::Task->run($task);
}

sub public_key {
   Rex::Config->set_public_key(@_);
}

sub private_key {
   Rex::Config->set_private_key(@_);
}

sub pass_auth {
   Rex::Config->set_password_auth(1);
}

sub parallelism {
   Rex::Config->set_parallelism($_[0]);
}

sub exit {
   Rex::Logger::info("Exiting Rex...");
   Rex::Logger::info("Cleaning up...");

   unlink("$::rexfile.lock") if($::rexfile);

   CORE::exit(@_);
}

sub logging {
   my $args = { @_ };

   if(exists $args->{'to_file'}) {
      Rex::Config->set_log_filename($args->{'to_file'});
   }
   elsif(exists $args->{'to_syslog'}) {
      Rex::Config->set_log_facility($args->{'to_syslog'});
   }
   else {
      Rex::Config->set_log_filename('rex.log');
   }
}

sub needs {
   my ($self, @args) = @_;

   Rex::Logger::debug("need to call tasks from $self");

   no strict 'refs';
   my @tasks_to_run = @{"${self}::tasks"};
   use strict;

   for my $task (@tasks_to_run) {
      if(@args && $task->{"name"} ~~ @args) {
         Rex::Logger::debug("Calling " . $task->{"name"});
         &{ $task->{"code"} };
      }
      elsif(! @args) {
         Rex::Logger::debug("Calling " . $task->{"name"});
         &{ $task->{"code"} };
      }
   }

}

sub say {
   CORE::say(@_);
}

1;
