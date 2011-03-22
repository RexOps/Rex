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

use Rex::Commands::Fs;
use File::Basename qw(basename);

@EXPORT = qw(download);

sub download {
   my $remote = shift;
   my $local = shift;

   unless(is_file($remote)) {
      die("$remote not found.");
   }
   
   unless(is_readable($remote)) {
      die("$remote is not readable.");
   }

   if(my $ssh = Rex::is_ssh()) {
      print STDERR "Downloading $remote -> $local\n";
      if(-d $local) {
         $local = $local . '/' . basename($remote);
      }

      $ssh->scp_get($remote, $local);
   } else {
      system("cp $remote $local");
   }
}

1
