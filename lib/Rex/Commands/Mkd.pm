#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::Mkd;

use strict;
use warnings;

require Exporter;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(mkd);

sub mkd {
   if(defined $::ssh) {
      my $cmd = "mkdir " . $_[0];
      $::ssh->send($cmd);

      my @ret = ();
      while(defined (my $line = $::ssh->read_line()) ) {
         $line =~ s/[\r\n]//gms;
         next if($line =~ m/^$/);
         push @ret, $line;
      }

      return join("\n", @ret);
   } else {
      mkdir($_[0]) or die($! . " -> " . join(" ", @_));
   }
}

1;
