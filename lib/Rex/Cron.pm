#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Cron;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

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
