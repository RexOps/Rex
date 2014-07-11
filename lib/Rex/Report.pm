#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Report;

use strict;
use warnings;

my $report;

sub create {
  my ( $class, $type ) = @_;

  if ($report) { return $report; }

  $type ||= "Base";

  my $c = "Rex::Report::$type";
  eval "use $c";

  if ($@) {
    die("No reporting class $type found.");
  }

  $report = $c->new;
  return $report;
}

sub destroy { $report = undef; }

1;
