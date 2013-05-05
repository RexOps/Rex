#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::CLI;
   
use strict;
use warnings;

use FindBin;
use File::Basename;
use Time::HiRes qw(gettimeofday tv_interval);
use Cwd qw(getcwd);

use Rex;
use Rex::Config;
use Rex::Group;
use Rex::Batch;
use Rex::TaskList;
use Rex::Cache;
use Rex::Logger;
use Rex::Output;

use Data::Dumper;

my $no_color = 0;
eval "use Term::ANSIColor";
if($@) { $no_color = 1; }

# no colors under windows
if($^O =~ m/MSWin/) {
   $no_color = 1;
}

# preload some modules
use Rex -base;

BEGIN {

   if(-d "lib") {
      use lib "lib";
   }

};

$|++;

my (%opts, @help, @exit);

if($#ARGV < 0) {
   @ARGV = qw(-h);
}

require Rex::Args;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub __run__ {

   my ($self, %more_args) = @_;

   Rex::Args->import(
      C => {},
      c => {},
      q => {},
      Q => {},
      F => {},
      T => {},
      h => {},
      v => {},
      d => {},
      s => {},
      m => {},
      S => { type => "string" },
      E => { type => "string" },
      o => { type => "string" },
      f => { type => "string" },
      M => { type => "string" },
      b => { type => "string" },
      e => { type => "string" },
      H => { type => "string" },
      u => { type => "string" },
      p => { type => "string" },
      P => { type => "string" },
      K => { type => "string" },
      G => { type => "string" },
      t => { type => "integer" },
      %more_args,
   );

   %opts = Rex::Args->getopts;

   if($opts{'Q'}) {
      my ($stdout, $stderr);
      open(my $newout, '>', \$stdout);
      select $newout;
      close(STDERR);
   }

   if($opts{'m'}) {
      $no_color = 1;
      $Rex::Logger::no_color = 1;
   }

   if($opts{'d'}) {
      $Rex::Logger::debug = $opts{'d'};
      $Rex::Logger::silent = 0;
   }

   if($opts{"c"}) {
      $Rex::Cache::USE = 1;
   }
   elsif($opts{"C"}) {
      $Rex::Cache::USE = 0;
   }

   Rex::Logger::debug("Command Line Parameters");
   for my $param (keys %opts) {
      Rex::Logger::debug("\t$param = " . $opts{$param});
   }

   if($opts{'h'}) {
      $self->__help__;
   } elsif($opts{'v'} && ! $opts{'T'}) {
      $self->__version__;
   }

   if($opts{'q'}) {
      $::QUIET = 1;
   }

   $::rexfile = "Rexfile";
   if($opts{'f'}) {
      Rex::Logger::debug("Using Rexfile: " . $opts{'f'});
      $::rexfile = $opts{'f'};
   } else {
      if ((! -e $::rexfile) && ($ARGV[0] && $ARGV[0] =~ /:/)) {
         #if there is no Rexfile, and the user asks for a longer path task, see if we can use it as the Rexfile
         #eg: rex -H $host Misc:Example:prepare --bar=baz
         $::rexfile = $ARGV[0];
         $::rexfile =~ s/:[^:]*$//;
         $::rexfile =~ s{:}{/}g;
         $::rexfile = 'Rex/'.$::rexfile.'.pm';
      }
   }

   FORCE_SERVER: {

      if($opts{'H'}) {
         if($opts{'H'} =~ m/^perl:(.*)/) {
            my $host_eval = eval( $1 );

            if(ref($host_eval) eq "ARRAY") {
               $::FORCE_SERVER = join(" ", @{$host_eval});
            }
            else {
               die("Perl Code have to return an array reference.");
            }
         }
         else {
            $::FORCE_SERVER = $opts{'H'};
         }
      }

   }

   if($opts{'o'}) {
      Rex::Output->get($opts{'o'});
   }

   # Load Rexfile before exec in order to suppport group exec
   if(-f $::rexfile) {
      Rex::Logger::debug("$::rexfile exists");

      Rex::Logger::debug("Checking Rexfile Syntax...");
      
      my $out = qx{$^X -MRex::Commands -MRex::Commands::Run -MRex::Commands::Fs -MRex::Commands::Download -MRex::Commands::Upload -MRex::Commands::File -MRex::Commands::Gather -MRex::Commands::Kernel -MRex::Commands::Pkg -MRex::Commands::Service -MRex::Commands::Sysctl -MRex::Commands::Tail -MRex::Commands::Process -c $::rexfile 2>&1};
      if($? > 0) {
         print $out;
      }

      if($? != 0) {
         exit 1;
      }

      if($^O !~ m/^MSWin/) {
         if(-f "$::rexfile.lock" && ! exists $opts{'F'}) {
            Rex::Logger::debug("Found $::rexfile.lock");
            my $pid = eval { local(@ARGV, $/) = ("$::rexfile.lock"); <>; };
            system("ps aux | awk -F' ' ' { print \$2 } ' | grep $pid >/dev/null 2>&1");
            if($? == 0) {
               Rex::Logger::info("Rexfile is in use by $pid.");
               CORE::exit 1;
            } else
            {
               Rex::Logger::info("Found stale lock file. Removing it.");
               Rex::global_sudo(0);
               CORE::unlink("$::rexfile.lock");
            }
         }
         
         Rex::Logger::debug("Creating lock-file ($::rexfile.lock)");
         open(my $f, ">$::rexfile.lock") or die($!);
         print $f $$; 
         close($f);
      }
      else {
         Rex::Logger::debug("Running on windows. Disabled syntax checking.");
         Rex::Logger::debug("Running on windows. Disabled lock file support.");
      }

      Rex::Logger::debug("Including/Parsing $::rexfile");

      Rex::Config->set_environment($opts{"E"}) if($opts{"E"});

      # turn sudo on with cli option s is used
      if(exists $opts{'s'}) {
         sudo("on");
      }
      if(exists $opts{'S'}) {
         sudo_password($opts{'S'});
      }

      if(exists $opts{'t'}) {
         parallelism($opts{'t'});
      }

      if($opts{'G'}) {
         $::FORCE_SERVER = "\0" . $opts{'G'};
      }

      if(-f "vars.db") {
         CORE::unlink("vars.db");
      }

      if(-f "vars.db.lock") {
         CORE::unlink("vars.db.lock");
      }

      eval {
         my $ok = do($::rexfile);
         Rex::Logger::info("eval your Rexfile.");
         if(! $ok) {
            Rex::Logger::info("There seems to be an error on some of your required files. $@", "error");
            my @dir = (dirname($::rexfile));
            for my $d (@dir) {
               opendir(my $dh, $d) or die($!);
               while(my $entry = readdir($dh)) {
                  if($entry =~ m/^\./) {
                     next;
                  }

                  if(-d "$d/$entry") {
                     push(@dir, "$d/$entry");
                     next;
                  }

                  if($entry =~ m/Rexfile/ || $entry =~ m/\.pm$/) {
                     # check files for syntax errors
                     my $check_out = qx{$^X -MRex::Commands -MRex::Commands::Run -MRex::Commands::Fs -MRex::Commands::Download -MRex::Commands::Upload -MRex::Commands::File -MRex::Commands::Gather -MRex::Commands::Kernel -MRex::Commands::Pkg -MRex::Commands::Service -MRex::Commands::Sysctl -MRex::Commands::Tail -MRex::Commands::Process -c $d/$entry 2>&1};
                     if($? > 0) {
                        print "$d/$entry\n";
                        print "--------------------------------------------------------------------------------\n";
                        print $check_out;
                        print "\n";
                     }
                  }
               }
               closedir($dh);
            }

            exit 1;
         }
      };

      if($@) { print $@ . "\n"; exit 1; }

   }
   if($opts{'e'}) {
      Rex::Logger::debug("Executing command line code");
      Rex::Logger::debug("\t" . $opts{'e'});

      # execute the given code
      my $code = "sub { \n";
      $code   .= $opts{'e'} . "\n";
      $code   .= "}";

      $code = eval($code);

      if($@) {
         Rex::Logger::info("Error in eval line: $@\n", "warn");
         exit 1;
      }

      if(exists $opts{'t'}) {
         parallelism($opts{'t'});
      }

      my $pass_auth = 0;

      if($opts{'u'}) {
         Rex::Commands::user($opts{'u'});
      }

      if($opts{'p'}) {
         Rex::Commands::password($opts{'p'});

         unless($opts{'P'}) {
            $pass_auth = 1;
         }
      }

      if($opts{'P'}) {
         Rex::Commands::private_key($opts{'P'});
      }

      if($opts{'K'}) {
         Rex::Commands::public_key($opts{'K'});
      }

      if($pass_auth) {
         pass_auth;
      }

      my @params = ();
      if($opts{'H'}) {
         push @params, split(/\s+/, $opts{'H'});
      }
      push @params, $code;
      push @params, "eval-line-desc";
      push @params, {};

      Rex::TaskList->create()->create_task("eval-line", @params);
      Rex::Commands::do_task("eval-line");
      CORE::exit(0);
   }
   elsif($opts{'M'}) {
      Rex::Logger::debug("Loading Rex-Module: " . $opts{'M'});
      my $mod = $opts{'M'};
      $mod =~ s{::}{/}g;
      require "$mod.pm";
   }

   #### check if some parameters should be overwritten from the command line
   CHECK_OVERWRITE: {

      my $pass_auth = 0;

      if($opts{'u'}) {
         Rex::Commands::user($opts{'u'});
         for my $task (Rex::TaskList->create()->get_tasks) {
            Rex::TaskList->create()->get_task($task)->set_user($opts{'u'});
         }
      }

      if($opts{'p'}) {
         Rex::Commands::password($opts{'p'});

         unless($opts{'P'}) {
            $pass_auth = 1;
         }

         for my $task (Rex::TaskList->create()->get_tasks) {
            Rex::TaskList->create()->get_task($task)->set_password($opts{'p'});
         }

      }

      if($opts{'P'}) {
         Rex::Commands::private_key($opts{'P'});

         for my $task (Rex::TaskList->create()->get_tasks) {
            $task->set_auth("private_key", $opts{'P'});
            Rex::TaskList->create()->get_task($task)->set_auth("private_key", $opts{'P'});
         }
      }

      if($opts{'K'}) {
         Rex::Commands::public_key($opts{'K'});

         for my $task (Rex::TaskList->create()->get_tasks) {
            Rex::TaskList->create()->get_task($task)->set_auth("public_key", $opts{'K'});
         }
      }

      if($pass_auth) {
         pass_auth;
      }

   }


   Rex::Logger::debug("Initializing Logger from parameters found in $::rexfile");

   if($opts{'T'} && $opts{'m'}) {
      # create machine readable tasklist
      my @tasks = Rex::TaskList->create()->get_tasks;
      for my $task (@tasks) {
         my $desc = Rex::TaskList->create()->get_desc($task);
         $desc =~ s/'/\\'/gms;
         print "'$task'" . " = '$desc'\n";
      }
   }
   elsif($opts{'T'}) {
      Rex::Logger::debug("Listing Tasks and Batches");
      _print_color("Tasks\n", "yellow");
      my @tasks = Rex::TaskList->create()->get_tasks;
      unless(@tasks) {
         print "   no tasks defined.\n";
         exit;
      }
      if(defined $ARGV[0]) {
        @tasks = map { Rex::TaskList->create()->is_task($_) ?  $_ : () } @ARGV;
      }
      for my $task (@tasks) {
         printf "  %-30s %s\n", $task, Rex::TaskList->create()->get_desc($task);
         if($opts{'v'}) {
             _print_color("      Servers: " . join(", ", @{ Rex::TaskList->create()->get_task($task)->{'server'} }) . "\n");
         }
      }
      _print_color("Batches\n", 'yellow') if(Rex::Batch->get_batchs);
      for my $batch (Rex::Batch->get_batchs) {
         printf "  %-30s %s\n", $batch, Rex::Batch->get_desc($batch);
         if($opts{'v'}) {
             _print_color("      " . join(" ", Rex::Batch->get_batch($batch)) . "\n");
         }
      }
      _print_color("Environments\n", "yellow");
      print "  " . join("\n  ", Rex::Commands->get_environments()) . "\n";

      my %groups = Rex::Group->get_groups;
      _print_color("Server Groups\n", "yellow") if(keys %groups);
      for my $group (keys %groups) {
         printf "  %-30s %s\n", $group, join(", ", @{ $groups{$group} });
      }

      Rex::global_sudo(0);
      Rex::Logger::debug("Removing lockfile") if(! exists $opts{'F'});
      CORE::unlink("$::rexfile.lock")               if(! exists $opts{'F'});
      CORE::exit 0;
   }

   eval {
      if($opts{'b'}) {
         Rex::Logger::debug("Running batch: " . $opts{'b'});
         my $batch = $opts{'b'};
         if(Rex::Batch->is_batch($batch)) {
            Rex::Batch->run($batch);
         }
      }

      if(defined $ARGV[0]) {
         for my $task (@ARGV) {
            if(Rex::TaskList->create()->is_task($task)) {
               Rex::Logger::debug("Running task: $task");
               Rex::TaskList->create()->run($task);
            }
         }
      }
   };

   if($@) {
      # this is always the child
      Rex::Logger::info("Error running task/batch: $@", "warn");
      CORE::exit(0);
   }

   my @exit_codes;

   if($Rex::WITH_EXIT_STATUS) {
      @exit_codes = Rex::TaskList->create()->get_exit_codes();
   }
#print ">> $$\n";
#print Dumper(\@exit_codes);
   # lock loeschen
   Rex::global_sudo(0);
   Rex::Logger::debug("Removing lockfile") if(! exists $opts{'F'});
   CORE::unlink("$::rexfile.lock")               if(! exists $opts{'F'});

   # delete shared variable db
   if(-f "vars.db") {
      CORE::unlink("vars.db");
   }

   if(-f "vars.db.lock") {
      CORE::unlink("vars.db.lock");
   }

   select STDOUT;

   for my $exit_hook (@exit) {
      &$exit_hook();
   }

   if($Rex::WITH_EXIT_STATUS) {
      for my $exit_code (@exit_codes) {
         if($exit_code != 0) {
            exit($exit_code);
         }
      }
   }
   else {
      exit(0);
   }

   sub _print_color {
       my ($msg, $color) = @_;
       $color = 'green' if !defined($color);

       if($no_color) {
           print $msg;
       }
       else {
           print colored([$color], $msg);
       }
   };



}

sub __help__ {

   print "(R)?ex - (Remote)? Execution\n";
   printf "  %-15s %s\n", "-b", "Run batch";
   printf "  %-15s %s\n", "-e", "Run the given code fragment";
   printf "  %-15s %s\n", "-E", "Execute task on the given environment";
   printf "  %-15s %s\n", "-H", "Execute task on these hosts";
   printf "  %-15s %s\n", "-G", "Execute task on these group";
   printf "  %-15s %s\n", "-u", "Username for the ssh connection";
   printf "  %-15s %s\n", "-p", "Password for the ssh connection";
   printf "  %-15s %s\n", "-P", "Private Keyfile for the ssh connection";
   printf "  %-15s %s\n", "-K", "Public Keyfile for the ssh connection";
   printf "  %-15s %s\n", "-T", "List all known tasks.";
   printf "  %-15s %s\n", "-Tv", "List all known tasks with all information.";
   printf "  %-15s %s\n", "-f", "Use this file instead of Rexfile";
   printf "  %-15s %s\n", "-h", "Display this help";
   printf "  %-15s %s\n", "-M", "Load Module instead of Rexfile";
   printf "  %-15s %s\n", "-v", "Display (R)?ex Version";
   printf "  %-15s %s\n", "-F", "Force. Don't regard lock file";
   printf "  %-15s %s\n", "-s", "Use sudo for every command";
   printf "  %-15s %s\n", "-S", "Password for sudo";
   printf "  %-15s %s\n", "-d", "Debug";
   printf "  %-15s %s\n", "-dd", "More Debug (includes Profiling Output)";
   printf "  %-15s %s\n", "-o", "Output Format";
   printf "  %-15s %s\n", "-c", "Turn cache ON";
   printf "  %-15s %s\n", "-C", "Turn cache OFF";
   printf "  %-15s %s\n", "-q", "Quiet mode. No Logging output";
   printf "  %-15s %s\n", "-Q", "Really quiet. Output nothing.";
   printf "  %-15s %s\n", "-t", "Number of threads to use.";
   print "\n";

   for my $code (@help) {
      &$code();
   }

   CORE::exit 0;

}

sub add_help {
   my ($self, $code) = @_;
   push(@help, $code);
}

sub add_exit {
   my ($self, $code) = @_;
   push(@exit, $code);
}

sub __version__ {
   print "(R)?ex " . $Rex::VERSION . "\n";
   CORE::exit 0;
}

1;
