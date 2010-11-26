#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Download;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(download);

sub download {
   my $remote = shift;
   my $local = shift;

   if(defined $::scp) {
      print STDERR "Downloading $remote -> $local\n";
      $::scp->scp(":".$remote, $local);
   } else {
      system("cp $remote $local");
   }
}

1
