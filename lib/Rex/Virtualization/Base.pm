#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::Base;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub execute {
  my ( $self, $action, $vmname, @opt ) = @_;

  my $mod = ref($self) . "::$action";
  eval "use $mod;";

  if ($@) {
    Rex::Logger::info("No action $action available.");
    die("No action $action available.");
  }

  return $mod->execute( $vmname, @opt );

}

1;
