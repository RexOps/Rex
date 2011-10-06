package Rex::Commands::SCM;

use strict;
use warnings;

use Rex::Logger;
use Rex::Config;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT %REPOS);
@EXPORT = qw(checkout);

Rex::Config->register_set_handler("repository" => sub {
   my ($name, %option) = @_;
   $REPOS{$name} = \%option;
});

sub checkout {
   my ($name, %data) = @_;

   my $type = $REPOS{"$name"}->{"type"} ? $REPOS{$name}->{"type"} : "git";
   my $class = "Rex::SCM::\u$type";

   my $co_to = exists $data{"path"} ? $data{"path"} : "";

   if($data{"path"}) {
      $data{"path"} = undef;
      delete $data{"path"};
   }

   eval "use $class;";
   if($@) {
      Rex::Logger::info("Error loading SCM: $@\n");
      die("Error loading SCM: $@");
   }

   my $scm = $class->new;

   my $repo = Rex::Config->get("repository");
   Rex::Logger::debug("Checking out $repo -> $co_to");
   $scm->checkout($REPOS{$name}, $co_to, \%data);
}

1;
