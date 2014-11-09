#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

use strict;

package Rex::CMDB::Base;

use warnings;

use Rex::Helper::Path;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub _parse_path {
  my ( $self, $path ) = @_;

  return parse_path($path);
}

1;
