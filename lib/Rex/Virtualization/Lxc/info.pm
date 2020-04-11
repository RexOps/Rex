#
# (c) Oleg Hardt <litwol@litwol.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Lxc::info;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
  my ( $class, $arg1 ) = @_;
  my @dominfo;

  if ( !$arg1 ) {
    die('Must define container ID');
  }

  Rex::Logger::debug("Getting lxc-info");

  my @container_info = i_run "lxc-info -n $arg1", fail_ok => 1;
  if ( $? != 0 ) {
    die("Error running lxc-info");
  }

  my %ret;
  for my $line (@container_info) {
    my ( $column, $value ) = split( ':', $line );

    # Trim white spaces.
    $column =~ s/^\s+|\s+$//g;
    $value  =~ s/^\s+|\s+$//g;

    $ret{$column} = $value;
  }

  return \%ret;
}

1;
