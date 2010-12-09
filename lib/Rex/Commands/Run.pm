#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Run;

use strict;
use warnings;

require Exporter;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(run);

sub run {
   my $cmd = shift;

   my @ret = ();
   if(defined $::ssh) {
      # irgendwas was noch so im puffer rumschwirrt einlesen bevor 
      # der send gemacht wird.
      while(defined (my $line = $::ssh->read_line()) ) { }

      $::ssh->send($cmd);

      while(defined (my $line = $::ssh->read_line()) ) {
         $line =~ s/[\r\n]//gms;
         next if($line =~ m/^$/);
         push @ret, $line;
      }

      shift @ret;
   } else {
      push @ret, `$cmd`;
      chomp @ret;
   }

   if(scalar(@ret) >= 1) {
      print join("\n", @ret);
      print "\n";
   }

   return join("\n", @ret);
}

1;
