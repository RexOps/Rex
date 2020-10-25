#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::attach;

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
    die("You have to define the attach options!");
  }

  my $options = _format_opts($opts);

  my $attach_command = "lxc-attach $options";

  i_run $attach_command, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running \"$attach_command\"");
  }

  return $opts->{newname};
}

sub _format_opts {
  my ($opts) = @_;

  # -n, --name=""
  # Assign the specified name to the container to be attached to.
  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  my $str = "-n $opts->{'name'}";

  # -B, --backingstorage=backingstorage
  # backingstorage type for the container
  if ( !exists $opts->{command} ) {
    die("You have to specify a COMMAND");
  }
  $str .= " -- $opts->{command}";

  return $str;
}

1;

