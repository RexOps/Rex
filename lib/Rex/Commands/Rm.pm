#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Rm;

use strict;
use warnings;

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(rm rd);

sub rm {
   my @files = @_;

   if(defined $::ssh) {
      for my $file (@files) {
         my $cmd = "rm -f $file";
         $::ssh->send($cmd);

         while(defined (my $line = $::ssh->read_line()) ) {
            $line =~ s/[\r\n]//gms;
            print "[rm] $line\n";
         }
      }
   } else {
      unlink(@files);
   }
}

sub rd {
   my @dirs = @_;

   if(defined $::ssh) {
      for my $dir (@dirs) {
         my $cmd = "rm -rf $dir";
         $::ssh->send($cmd);

         while(defined (my $line = $::ssh->read_line()) ) {
            $line =~ s/[\r\n]//gms;
            print "[rd] $line\n";
         }
      }
   } else {
      for my $dir (@dirs) {
         my @line = qx{rm -rf $dir};
         print join("\n[rd] ", @line);
      }
   }
}

1;
