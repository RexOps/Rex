#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Task;

use strict;
use warnings;
use Net::SSH::Expect;
use Rex::Helper::SCP;

use Data::Dumper;

use vars qw(%tasks);

sub create_task {
   my $class = shift;
   my $task_name = shift;
   my $desc = pop;

   my $func;
   if(ref($desc) eq "CODE") {
      $func = $desc;
      $desc = "";
   } else {
      $func = pop;
   }

   my $group = 'ALL';
   my @server = ();
   if(scalar(@_) >= 1) {
      if($_[0] eq "group") {
         $group = $_[1];
         if(Rex::Group->is_group($group)) {
            @server = Rex::Group->get_group($group);
         } else {
            print STDERR "Group $group not found!\n";
            exit 1;
         }
      } else {
         @server = @_;
      }
   }

   $tasks{$task_name} = {
      func => $func,
      server => [ @server ],
      desc => $desc
   };
}

sub get_tasks {
   my $class = shift;

   return sort { $a cmp $b } keys %tasks;
}

sub get_desc {
   my $class = shift;
   my $task = shift;

   return $tasks{$task}->{"desc"};
}

sub is_task {
   my $class = shift;
   my $task = shift;
   
   if(exists $tasks{$task}) { return 1; }
   return 0;
}

sub run {
   my $class = shift;
   my $task = shift;
   my $ret;

   print STDERR "Running task: $task\n";
   my $code = $tasks{$task}->{'func'};
   my @server = @{$tasks{$task}->{'server'}};

   if(scalar(@server) > 0) {

      for $::server (@server) {
         print STDERR "Connecting to $::server (" . Rex::Config->get_user . ")\n";
         if(Rex::Config->get_password) {
            $::ssh = Net::SSH::Expect->new(
               host => $::server,
               user => Rex::Config->get_user,
               password => Rex::Config->get_password
            );

            $::scp = Rex::Helper::SCP->new(
               host => $::server,
               user => Rex::Config->get_user,
               password => Rex::Config->get_password
            );

            $::ssh->login();
         } else {
            $::ssh = Net::SSH::Expect->new(
               host => $::server,
               user => Rex::Config->get_user
            );

            $::scp = Rex::Helper::SCP->new(
               host => $::server,
               user => Rex::Config->get_user
            );

            $::ssh->run_ssh();
         }

         #$::ssh->exec("stty raw -echo");
         $::ssh->exec("/bin/bash --noprofile --norc");

         $ret = &$code;

         $::ssh->exec("exit");
         $::ssh->close();
      }
   } else {
      $ret = &$code;
   }

   return $ret;
}

1;
