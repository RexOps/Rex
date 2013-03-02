#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Helper::Encode;

use strict;
use warnings;

my %escapes;
for (0..255) {
   $escapes{chr($_)} = sprintf("%%%02X", $_);
}

sub url_encode{
   my ($txt)=@_;
   $txt =~ s/([^A-Za-z0-9_])/$escapes{$1}/g;
   return $txt;
}

sub url_decode{
   my ($txt)=@_;
   $txt=~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
   return $txt;
}

1;
