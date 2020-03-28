#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::File::Base;

use strict;
use warnings;

# VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->{file_write_encoding} = Rex::Config->get_file_write_encoding;

  return $self;
}

sub open  { die("Must be implemented by Interface Class."); }
sub read  { die("Must be implemented by Interface Class."); }
sub write { die("Must be implemented by Interface Class."); }
sub close { die("Must be implemented by Interface Class."); }
sub seek  { die("Must be implemented by Interface Class."); }

sub get_file_write_encoding {
  my $self = shift;
  return $self->{file_write_encoding};
}

1;
