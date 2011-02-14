#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Task;

use strict;
use warnings;
use Net::SSH2;
use Rex::Fork::Manager;

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
   my @server = @{$tasks{$task}->{'server'}};

   my($user, $pass);
   if(ref($server[-1]) eq "HASH") {
      my $data = pop(@server);
      $user = $data->{'user'};
      $pass = $data->{'password'};
   } else {
      $user = Rex::Config->get_user;
      $pass = Rex::Config->get_password;
   }
   my $timeout = Rex::Config->get_timeout;

   my @params = @ARGV[1..$#ARGV];
   my %opts = ();
   for my $p (@params) {
      my($key, $val) = split(/=/, $p, 2);
      $key = substr($key, 2);

      if($val) { $opts{$key} = $val; next; }
      $opts{$key} = 1;
   }

   if(scalar(@server) > 0) {

      my @children;

      my $fm = Rex::Fork::Manager->new(max => Rex::Config->get_parallelism);

      for $::server (@server) {
         $fm->add(sub {
            $::ssh = Net::SSH2->new;

            my $fail_connect = 0;
            print STDERR "Connecting to $::server (" . $user . ")\n";
            CON_SSH:
               unless($::ssh->connect($::server, 22, Timeout => Rex::Config->get_timeout)) {
                  ++$fail_connect;
                  goto CON_SSH if($fail_connect < 3);
                  print STDERR "Can't connect to $::server\n";
                  CORE::exit; # kind beenden
               }

            if(Rex::Config->get_password_auth) {
               $::ssh->auth_password($user, $pass);
            } else {
               $::ssh->auth_publickey($user, Rex::Config->get_public_key, Rex::Config->get_private_key, $pass);
            }

            $ret = _exec($task, \%opts);
            $::ssh->disconnect();

            CORE::exit; # exit child
         }, 1); # [END] $fm->add
      }

      $fm->wait_for_all;

   } else {
      $ret = _exec($task, \%opts);
   }

   return $ret;
}

sub _exec {
   my $task = shift;
   my $opts = shift;

   my $code = $tasks{$task}->{'func'};
   return &$code($opts);
}

1;
