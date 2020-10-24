#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::create;

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
    die("You have to define the create options!");
  }

  my $options = _format_opts($opts);

  my $create_command = "lxc-create $options";
  i_run $create_command, fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running \"$create_command\"");
  }

  return $opts->{name};
}

sub _format_opts {
  my ($opts) = @_;

  # -n, --name=""
  # Assign the specified name to the container.
  if ( !exists $opts->{"name"} ) {
    die("You have to give a name.");
  }

  # -t, --template=""
  # Assign the specified template to the container.
  if ( !exists $opts->{"template"} ) {
    die("You have to specify a template.");
  }

  my $str = "-n $opts->{'name'} -t $opts->{'template'}";

  # BDEV Backing store type to use
  if ( exists $opts->{bdev} ) {
    $str .= " -B $opts->{bdev}";
  }

  # -f, --config=CONFIG
  # Initial configuration file.
  if ( exists $opts->{config} ) {
    $str .= " -f $opts->{config}";
  }

  return $str;
}

1;
