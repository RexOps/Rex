#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::destroy;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $name, %opt ) = @_;

  my $opts = \%opt;
  $opts->{name} = $name;

  unless ($opts) {
    die("You have to define the destroy options!");
  }

  Rex::Logger::debug("destroying container $opts->{name}");

  my $options = _format_opts($opts);

  my $destroy_command = "lxc-destroy $options";

  i_run $destroy_command, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error destroying container $opts->{name}");
  }

  return $opts->{name};
}

sub _format_opts {
  my ($opts) = @_;

  # -n, --name=""
  # Assign the specified name to the container.
  if ( !exists $opts->{name} ) {
    die("You have to give a name.");
  }

  my $str = "-n $opts->{name}";

  # -s, --snapshots=""
  # destroy including all snapshots.
  if ( exists $opts->{snapshots} ) {
    $str .= " -s";
  }

  # -f, --force
  # wait for the container to shut down.
  if ( exists $opts->{force} ) {
    $str .= " -f";
  }

  return $str;
}

1;
