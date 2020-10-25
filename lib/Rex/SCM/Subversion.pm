package Rex::SCM::Subversion;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Cwd qw(getcwd);
use Rex::Commands::Fs;
use Rex::Helper::Run;

use vars qw($CHECKOUT_COMMAND);

BEGIN {
  my $version = qx{svn --version --quiet 2>/dev/null};
  if ($version) {
    my @parts = split( /\./, $version );

    if ( $parts[1] <= 5 ) {
      $CHECKOUT_COMMAND = "svn --non-interactive %s checkout %s %s";
    }
    else {
      $CHECKOUT_COMMAND =
        "svn --non-interactive --trust-server-cert %s checkout %s %s";
    }
  }
}

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub checkout {
  my ( $self, $repo_info, $checkout_to, $checkout_opt ) = @_;

  my $special_opts = "";

  if ( exists $repo_info->{"username"} ) {
    $special_opts = " --username  '" . $repo_info->{"username"} . "'";
  }

  if ( exists $repo_info->{"password"} ) {
    $special_opts .= " --password  '" . $repo_info->{"password"} . "'";
  }

  my $checkout_cmd;

  if ( !is_dir($checkout_to) ) {
    $checkout_cmd = sprintf( $CHECKOUT_COMMAND,
      $special_opts, $repo_info->{"url"}, $checkout_to );
  }
  elsif ( is_dir("$checkout_to/.svn") ) {
    $checkout_cmd = "svn up $checkout_to";
  }
  else {
    Rex::Logger::info( "Error checking out repository.", "warn" );
    die("Error checking out repository.");
  }
  Rex::Logger::debug("checkout_cmd: $checkout_cmd");

  Rex::Logger::info( "Cloning "
      . $repo_info->{"url"} . " to "
      . ( $checkout_to ? $checkout_to : "." ) );
  my $out = i_run "$checkout_cmd", fail_ok => 1;
  unless ( $? == 0 ) {
    Rex::Logger::info( "Error checking out repository.", "warn" );
    Rex::Logger::info($out);
    die("Error checking out repository.");
  }

}

1;
