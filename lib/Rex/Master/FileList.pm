#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Master::FileList;

use strict;
use warnings;

use Cwd qw(getcwd);

sub run {
   my ($class, $env) = @_;

   my $ret = "";

   my @dirs = (".");

   for my $dir (@dirs) {
      opendir(my $dh, $dir) or return "ERROR";
      while(my $entry = readdir($dh)) {
         next if $entry =~ /^\./;
         push @dirs, "$dir/$entry" if -d "$dir/$entry";
         my $p_dir = "$dir/$entry";
         $p_dir =~ s/^\.\///;

         $ret .= "$p_dir\n";
      }
      closedir($dh);
   }

   return $ret;
}

1;
