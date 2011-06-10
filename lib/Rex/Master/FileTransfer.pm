#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Master::FileTransfer;

use strict;
use warnings;

use Cwd qw(getcwd);

sub run {
   my ($class, $env) = @_;

   my $file = $env->{"REQUEST_URI"};
   $file =~ s/^\///;
   my $pwd = getcwd();
   $file = getcwd() . "/" . $file;

   if(-f $file && $file =~ /^$pwd/) {
      return eval { local(@ARGV, $/) = ($file); <>; };
   }
   else {
      return "404 NOT FOUND\n";
   }
}

1;
