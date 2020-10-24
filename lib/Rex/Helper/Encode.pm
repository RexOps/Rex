#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::Encode;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(func_to_json);

my %escapes;
for ( 0 .. 255 ) {
  $escapes{ chr($_) } = sprintf( "%%%02X", $_ );
}

sub url_encode {
  my ($txt) = @_;
  $txt =~ s/([^A-Za-z0-9_])/$escapes{$1}/g;
  return $txt;
}

sub url_decode {
  my ($txt) = @_;
  $txt =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
  return $txt;
}

sub func_to_json {

  return q|
  sub to_json {
    my ($ref) = @_;

    my $s = "";

    if(ref $ref eq "ARRAY") {
      $s .= "[";
      for my $itm (@{ $ref }) {
        if(substr($s, -1) ne "[") {
          $s .= ",";
        }
        $s .= to_json($itm);
      }
      return $s . "]";
    }
    elsif(ref $ref eq "HASH") {
      $s .= "{";
      for my $key (keys %{ $ref }) {
        if(substr($s, -1) ne "{") {
          $s .= ",";
        }
        $s .= "\"$key\": " . to_json($ref->{$key});
      }
      return $s . "}";
    }
    else {
      if($ref =~ /^0\d+/) {
        return "\"$ref\"";
      }
      elsif($ref =~ /^\d+$/) {
        return $ref;
      }
      else {
        $ref =~ s/'/\\\'/g;
        return "\"$ref\"";
      }
    }
  }

  |;

}

1;
