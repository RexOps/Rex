#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Cron;

use strict;
use warnings;

use Rex::Commands::Gather;

sub create {
  my ($class) = @_;

  my $type = "Linux";
  if ( operating_system_is("SunOS") ) {
    $type = "SunOS";
  }

  my $klass = "Rex::Cron::$type";
  eval "use $klass;";
  if ($@) {
    die("Error creating cron class: $klass\n$@");
  }

  return $klass->new;
}

1;
