#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Box;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Config;
use Rex::Logger;

my %BOX_PROVIDER;

sub register_box_provider {
  my ( $class, $service_name, $service_class ) = @_;
  $BOX_PROVIDER{"\L$service_name"} = $service_class;
  return 1;
}

sub create {
  my ( $class, @opts ) = @_;

  my $type    = Rex::Config->get("box_type")    || "VBox";
  my $options = Rex::Config->get("box_options") || {};

  my $klass = "Rex::Box::${type}";

  if ( exists $BOX_PROVIDER{$type} ) {
    $klass = $BOX_PROVIDER{$type};
  }

  Rex::Logger::debug("Using $klass as box provider");
  eval "use $klass;";

  if ($@) {
    Rex::Logger::info("Box Class $klass not found.");
    die("Box Class $klass not found.");
  }

  return $klass->new( @opts, options => $options );
}

1;
