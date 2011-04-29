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

   unless($remote) {
      $remote = basename($local);
   }

   if(! -f $local) {
      Rex::Logger::info("File Not Found: $local");
      return 1;
   }

   if(my $ssh = Rex::is_ssh()) {
      Rex::Logger::info("Uploadling $local -> $remote");
      if(is_dir($remote)) {
         $remote = $remote . '/' . basename($local);
      }

      unless($ssh->scp_put($local, $remote)) {
         Rex::Logger::debug("upload: $remote is not writable");
         die("upload: $remote is not writable.");
      }
   } else {
      if(-d $remote) {
         $remote = $remote . '/' . basename($remote);
      }
      unless(system("cp $local $remote")) {
         Rex::Logger::debug("upload: $remote is not writable");
         die("upload: $remote is not writable.");
      }
   }
}

1;
