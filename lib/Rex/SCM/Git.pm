package Rex::SCM::Git;

use strict;
use warnings;

use Cwd qw(getcwd);
use Rex::Commands::Run;

use vars qw($CHECKOUT_COMMAND $CLONE_COMMAND);

$CLONE_COMMAND    = "git clone %s %s";
$CHECKOUT_COMMAND = "git checkout -b %s origin/%s";

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub checkout {
   my ($self, $repo_info, $checkout_to, $checkout_opt) = @_;
   my $clone_cmd = sprintf($CLONE_COMMAND, $repo_info->{"url"}, $checkout_to);
   Rex::Logger::debug("clone_cmd: $clone_cmd");

   Rex::Logger::info("cloning " . $repo_info->{"url"} . " to $checkout_to");
   my $out = run "$clone_cmd";
   unless($? == 0) {
      Rex::Logger::info("Error cloning repository.");
      Rex::Logger::info($out);
      exit 1;
   }

   Rex::Logger::debug($out);

   if(exists $checkout_opt->{"branch"}) {
      my $cwd = getcwd;

      unless($checkout_to) {
         $checkout_to = [ split(/\//, $repo_info->{"url"}) ]->[-1];
         $checkout_to =~ s/\.git$//;
      }

      Rex::Logger::debug("chdir: $checkout_to");
      chdir($checkout_to);

      my $checkout_cmd = sprintf($CHECKOUT_COMMAND, $checkout_opt->{"branch"}, $checkout_opt->{"branch"});
      Rex::Logger::debug("checkout_cmd: $checkout_cmd");

      Rex::Logger::info("switching to branch " . $checkout_opt->{"branch"});

      $out = run "$checkout_cmd";
      Rex::Logger::debug($out);

      Rex::Logger::debug("chdir: $cwd");
      chdir($cwd);
   }
}

1;
