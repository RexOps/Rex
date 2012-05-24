#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Args;
   
use strict;
use warnings;

use vars qw(%opts);

sub import {

   my @params = @ARGV[1..$#ARGV];

   for my $p (@params) {
      my($key, $val) = split(/=/, $p, 2);
      $key =~ s/^--//;

      if($val) { $opts{$key} = $val; next; }
      $opts{$key} = 1;
   }

}

sub get { return %opts; }

1;
