#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Upload;

use strict;
use warnings;

require Exporter;
use File::Basename qw(basename);
use Rex::Commands::Fs;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(upload);

sub upload {
   my $local = shift;
   my $remote = shift;

   if(! -f $local) { print STDERR "File Not Found: $local\n"; return 1; }

   if(defined $::ssh) {
      print STDERR "Uploadling $local -> $remote\n";
      if(is_dir($remote)) {
         $remote = $remote . '/' . basename($local);
      }

      unless($::ssh->scp_put($local, $remote)) {
         die("upload: $remote is not writeable.");
      }
   } else {
      if(-d $remote) {
         $remote = $remote . '/' . basename($remote);
      }
      system("cp $local $remote") or die("upload: $remote is not writeable.");
   }
}

1
