#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::File::Base;

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

sub open  { die("Must be implemented by Interface Class."); }
sub read  { die("Must be implemented by Interface Class."); }
sub write { die("Must be implemented by Interface Class."); }
sub close { die("Must be implemented by Interface Class."); }
sub seek  { die("Must be implemented by Interface Class."); }

1;
