#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Report;

use strict;
use warnings;
use Data::Dumper;
use Module::Runtime qw(use_module);

# VERSION

my $report;

sub create {
  my ( $class, $type ) = @_;
  if ( $report && $type && ref($report) =~ m/::\Q$type\E$/ ) { return $report; }

  $type ||= "Base";

  my $c = "Rex::Report::$type";
  eval { use_module( $c ) }
      or die("No reporting class $type found.");

  $report = $c->new;
  return $report;
}

sub destroy { $report = undef; }

1;
