#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Report;

use v5.12.5;
use warnings;
use Data::Dumper;

our $VERSION = '9999.99.99_99'; # VERSION

my $report;

sub create {
  my ( $class, $type ) = @_;
  if ( $report && $type && ref($report) =~ m/::\Q$type\E$/ ) { return $report; }

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
