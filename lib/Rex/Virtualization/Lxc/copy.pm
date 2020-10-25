#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::copy;

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
    die("You have to define the copy options!");
  }

  my $options = _format_opts($opts);

  my $copy_command = "lxc-copy $options";
  i_run $copy_command, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running \"$copy_command\"");
  }

  return $opts->{newname};
}

sub _format_opts {
  my ($opts) = @_;

  # -n, --name=""
  # Assign the specified name to the container to be copied.
  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  # -N, --newname=""
  # Assign the specified name to the new container.
  if ( !exists $opts->{"newname"} ) {
    die("You have to specify a newname.");
  }

  my $str = "-n $opts->{'name'} -N $opts->{'newname'}";

  # -s, --snapshot
  # create snapshot instead of clone
  if ( exists $opts->{snapshot} ) {
    $str .= " -s";
  }

  # -B, --backingstorage=backingstorage
  # backingstorage type for the container
  if ( exists $opts->{backingstorage} ) {
    $str .= " -B $opts->{backingstorage}";
  }

  # -e, --ephemeral
  # create snapshot instead of clone
  if ( exists $opts->{ephemeral} ) {
    $str .= " -e";
  }

  # -m, --mount
  # create snapshot instead of clone
  if ( exists $opts->{mount} ) {
    $str .= " -m $opts->{mount}";
  }

  return $str;
}

1;
