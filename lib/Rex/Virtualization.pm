#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Virtualization;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
use Rex::Config;

my %VM_PROVIDER;

Rex::Config->register_config_handler(
  virtualization => sub {
    my ($param) = @_;

    if ( ref($param) eq '' ) {

#support 'set virtualization => 'LibVirt', but leave the way open for using a hash in future
#other virtualisation drivers may need more settings...
      $param = { type => $param };
    }

    if ( exists $param->{type} ) {
      Rex::Config->set( virtualization => $param->{type} );
    }
  }
);

sub register_vm_provider {
  my ( $class, $service_name, $service_class ) = @_;
  $VM_PROVIDER{"\L$service_name"} = $service_class;
  return 1;
}

sub create {
  my ( $class, $wanted_provider ) = @_;

  $wanted_provider ||= Rex::Config->get("virtualization");
  if ( ref($wanted_provider) ) {
    $wanted_provider = $wanted_provider->{type} || "LibVirt";
  }

  if ( !$wanted_provider ) {
    die
      "No virtualization provider set.\nPlease use `set virtualization => 'YourProvider';` to set one,\nor see `perldoc Rex::Commands::Virtualization` for more options";
  }

  my $klass = "Rex::Virtualization::$wanted_provider";

  if ( exists $VM_PROVIDER{$wanted_provider} ) {
    $klass = $VM_PROVIDER{$wanted_provider};
  }

  eval "use $klass";

  if ($@) {
    die
      "Failed loading given virtualization module.\nTried to load <$klass>.\nError: $@\n";
  }

  Rex::Logger::debug("Using $klass for virtualization");

  my $mod = $klass->new;
  return $mod;
}

1;
