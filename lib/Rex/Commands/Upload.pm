#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Upload;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(upload);

sub upload {
   my $local = shift;
   my $remote = shift;

   if(! -f $local) { print STDERR "File Not Found: $local\n"; return 1; }

   if(defined $::ssh) {
      print STDERR "Uploadling $local -> $remote\n";
      $::ssh->scp_put($local, $remote);
   } else {
      system("cp $local $remote");
   }
}

1
