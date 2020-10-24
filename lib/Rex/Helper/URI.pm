#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::URI;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

sub encode {
  my ($part) = @_;
  $part =~ s/([^\w\-\.\@])/_encode_char($1)/eg;
  return $part;
}

sub _encode_char {
  my ($char) = @_;
  return "%" . sprintf "%lx", ord($char);
}

1;
