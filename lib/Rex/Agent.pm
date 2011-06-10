#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Agent;

use strict;
use warnings;

use Net::Server::Daemonize qw(daemonize);
use Sys::Hostname;
use LWP::UserAgent;
use File::Path qw(make_path);

use Rex;
use Rex::Config;
use Rex::Group;
use Rex::Batch;
use Rex::Task;
use Rex::Commands;

# preload some modules
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::Download;
use Rex::Commands::Upload;

use Cwd qw(getcwd);

use vars qw($config);

sub run_now {
   my $class = shift;
   $config = { @_ };

   if($config->{'daemon'}) {
      daemonize(
         $config->{'user'} || 'root',
         $config->{'group'} || 'root',
         $config->{'pid_file'} || '/var/run/rex-agent.pid',
      );
   }

   unless(-d $config->{'cache_dir'}) {
      mkdir($config->{'cache_dir'});
   }

   while(1) {


      my $pid = fork();
      if(not defined $pid) {
         die("Fork not working... no resources?");
      }
      elsif($pid == 0) {

         $0 = "[rex-agent (child) running...]";

         get_files();

         eval {

            chdir($config->{'cache_dir'});
            $::rexfile = "Rexfile";

            if(-f "$::rexfile.lock") {
               Rex::Logger::debug("Found $::rexfile.lock");
               my $pid = eval { local(@ARGV, $/) = ("$::rexfile.lock"); <>; };
               system("ps aux | awk -F' ' ' { print \$2 } ' | grep $pid >/dev/null 2>&1");
               if($? == 0) {
                  Rex::Logger::info("Rexfile is in use by $pid.");
                  die;
               } else
               {
                  Rex::Logger::info("Found stale lock file. Removing it.");
                  unlink("$::rexfile.lock");
               }
            }
            
            Rex::Logger::debug("Checking Rexfile Syntax...");
            system("$^X -MRex::Commands -c $::rexfile");
            if($? != 0) {
               die("Syntax Error");
            }

            Rex::Logger::debug("Creating lock-file ($::rexfile.lock)");
            open(my $f, ">$::rexfile.lock") or die($!);
            print $f $$; 
            close($f);

            Rex::Logger::debug("Including/Parsing $::rexfile");
            eval {
               do($::rexfile);
            };

            if($@) { print $@ . "\n"; die($@); }

            my $hostname = hostname();
            my ($shortname) = ($hostname =~ m/^([^\.]+)\.?/);
            Rex::Logger::debug("My Hostname: " . $hostname);
            Rex::Logger::debug("My Shortname: " . $shortname);
            
            my @tasks = Rex::Task->get_tasks_for($shortname);
            Rex::Logger::debug("Tasks to run:");
            Rex::Logger::debug("    $_" ) for @tasks;

            parallelism 1;

            for my $task (@tasks) {
               if(Rex::Task->is_task($task)) {
                  Rex::Logger::debug("Running task: $task");
                  Rex::Task->run($task, $shortname);
               }
            }

            CORE::unlink("$::rexfile.lock");

         };

         if($@) {
            CORE::unlink("$::rexfile.lock");
            Rex::Logger::debug("Error running tasks. $@");
         }

         CORE::exit;

      } # END FORK
      else {
         $0 = "[rex-agent parent - waiting for child to come home...]";
         waitpid($pid, 0);

         $0 = "[rex-agent waiting...]";
         Rex::Logger::debug('Sleeping for ' . $config->{'interval'} . ' seconds.');
         sleep $config->{'interval'};
      }

   }

}

sub get_files {

   Rex::Logger::debug("Requesting filelist...");

   my $base_url = 'http://' . $config->{'server'} . ':' . $config->{'port'} . '/';

   my $files = get($base_url);

   Rex::Logger::debug($files);

   my @files = split(/\n/, $files);

   for my $file (@files) {
   
      my ($dir) = ($file =~ m/^(.*)\//);
      if($dir && ! -d $config->{'cache_dir'} . "/" . $dir) {
         make_path($config->{'cache_dir'} . "/" . $dir);
      }

      open(my $fh, ">", $config->{'cache_dir'} . '/' . $file) or die($!);
      print $fh get($base_url . $file);
      close($fh);

   }
}

sub get {
   my ($url) = @_;

   Rex::Logger::debug("Requesting: $url");

   my $ua = LWP::UserAgent->new;
   $ua->timeout($config->{'timeout'});
   $ua->env_proxy;

   my $response = $ua->get($url);

   if($response->is_success) {
      return $response->content;
   }
   else {
      Rex::Logger::debug("Error getting $url " . $response->status_line);
   }

}

1;
