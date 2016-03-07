#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Cron;

use strict;
use warnings;

# VERSION

use Rex::Commands::Gather;
use List::Util qw'first';

sub create {
  my ($class) = @_;

  my $type = "Linux";
  if ( operating_system_is("SunOS") ) {
    $type = "SunOS";
  }

  my $exec = Rex::Interface::Exec->create;

  # here we're using first and not any, because in older perl versions
  # there is no any() function in List::Util.
  if ( operating_system_is( "FreeBSD", "OpenBSD", "NetBSD" )
    && first { $exec->shell->name eq $_ } (qw/csh ksh tcsh/) )
  {
    $type = "FreeBSD";
  }

  my $klass = "Rex::Cron::$type";
  eval "use $klass;";
  if ($@) {
    die("Error creating cron class: $klass\n$@");
  }

  return $klass->new;
}

1;
