#
# Shameless copy of Text::Glob
#   https://metacpan.org/pod/Text::Glob
#
package Rex::Helper::Glob;
use strict;
use Exporter;
use vars qw/$VERSION @ISA @EXPORT_OK
  $strict_leading_dot $strict_wildcard_slash/;
$VERSION   = '0.09';
@ISA       = 'Exporter';
@EXPORT_OK = qw( glob_to_regex glob_to_regex_string match_glob );

$strict_leading_dot    = 0;
$strict_wildcard_slash = 0;

use constant debug => 0;

sub glob_to_regex {
  my $glob = shift;
  if ( ref $glob eq "Regexp" ) {
    return $glob;
  }
  my $regex = glob_to_regex_string($glob);
  return qr/^$regex$/;
}

sub glob_to_regex_string {
  my $glob = shift;
  my ( $regex, $in_curlies, $escaping );
  local $_;
  my $first_byte = 1;
  for ( $glob =~ m/(.)/gs ) {
    if ($first_byte) {
      if ($strict_leading_dot) {
        $regex .= '(?=[^\.])' unless $_ eq '.';
      }
      $first_byte = 0;
    }
    if ( $_ eq '/' ) {
      $first_byte = 1;
    }
    if ( $_ eq '.'
      || $_ eq '('
      || $_ eq ')'
      || $_ eq '|'
      || $_ eq '+'
      || $_ eq '^'
      || $_ eq '$'
      || $_ eq '@'
      || $_ eq '%' )
    {
      $regex .= "\\$_";
    }
    elsif ( $_ eq '*' ) {
      $regex .=
          $escaping              ? "\\*"
        : $strict_wildcard_slash ? "[^/]*"
        :                          ".*";
    }
    elsif ( $_ eq '?' ) {
      $regex .=
          $escaping              ? "\\?"
        : $strict_wildcard_slash ? "[^/]"
        :                          ".";
    }
    elsif ( $_ eq '{' ) {
      $regex .= $escaping ? "\\{" : "(";
      ++$in_curlies unless $escaping;
    }
    elsif ( $_ eq '}' && $in_curlies ) {
      $regex .= $escaping ? "}" : ")";
      --$in_curlies unless $escaping;
    }
    elsif ( $_ eq ',' && $in_curlies ) {
      $regex .= $escaping ? "," : "|";
    }
    elsif ( $_ eq "\\" ) {
      if ($escaping) {
        $regex .= "\\\\";
        $escaping = 0;
      }
      else {
        $escaping = 1;
      }
      next;
    }
    else {
      $regex .= $_;
      $escaping = 0;
    }
    $escaping = 0;
  }
  print "# $glob $regex\n" if debug;

  return $regex;
}

sub match_glob {
  print "# ", join( ', ', map { "'$_'" } @_ ), "\n" if debug;
  my $glob  = shift;
  my $regex = glob_to_regex $glob;
  local $_;
  grep { $_ =~ $regex } @_;
}

1;
__END__
