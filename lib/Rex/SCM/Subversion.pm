package Rex::SCM::Subversion;

use strict;
use warnings;

use Cwd qw(getcwd);
use Rex::Commands::Run;

use vars qw($CHECKOUT_COMMAND);

$CHECKOUT_COMMAND = "svn %s checkout %s %s";

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub checkout {
   my ($self, $repo_info, $checkout_to, $checkout_opt) = @_;

   my $special_opts = "";

   if(exists $checkout_opt->{"username"}) {
      $special_opts = " --username  " . $checkout_opt->{"username"};
   }

   if(exists $checkout_opt->{"password"}) {
      $special_opts .= " --password  " . $checkout_opt->{"password"};
   }

   my $checkout_cmd = sprintf($CHECKOUT_COMMAND, $special_opts, $repo_info->{"url"}, $checkout_to);
   Rex::Logger::debug("checkout_cmd: $checkout_cmd");

   Rex::Logger::info("checkout " . $repo_info->{"url"} . " to $checkout_to");
   my $out = run "$checkout_cmd";
   unless($? == 0) {
      Rex::Logger::info("Error checking out repository.");
      Rex::Logger::info($out);
      exit 1;
   }

}

1;
