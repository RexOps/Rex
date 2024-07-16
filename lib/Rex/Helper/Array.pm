#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Helper::Array;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(array_uniq in_array);

sub array_uniq {
  my (@array) = @_;

  my %all = ();
  @all{@array} = 1;
  return keys %all;
}

sub in_array {
  my ( $needle, @haystack ) = @_;

  my ($ret) = grep {
    if ( ref $needle eq "RegExp" && $_ =~ $needle ) {
      return $_;
    }
    elsif ( $_ eq $needle ) {
      return $_;
    }
  } @haystack;

  return $ret;
}

1;
