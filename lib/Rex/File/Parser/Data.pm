#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::File::Parser::Data;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub read {
  my ( $self, $file ) = @_;
  return $self->_read_file($file);
}

sub _read_file {
  my ( $self, $file ) = @_;

  my $content = "";

  my $in_file = 0;
  for my $line ( @{ $self->{"data"} } ) {
    chomp $line;

    if ( $line eq "\@end" ) {
      $in_file = 0;
      next;
    }

    if ($in_file) {
      $content .= $line . $/;
    }

    if ( $line eq "\@$file" ) {
      $in_file = 1;
      next;
    }
  }

  return $content;
}

sub get {
  my ( $self, $file ) = @_;
}

1;
