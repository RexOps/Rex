#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::File;

use strict;
use warnings;

require Exporter;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(file_write file_close);

use vars qw(%file_handles);

sub file_write {
   my $fh;
   open($fh, ">", $_[0]) or die($!);
   $file_handles{$_[0]} = $fh;
   return $fh;
}

sub file_close {
   for my $f (keys %file_handles) {
      if($file_handles{$f} == $_[0]) {
         $file_handles{$f} = undef;
         delete $file_handles{$f};
         close($_[0]);
      }
   }
}

1;
