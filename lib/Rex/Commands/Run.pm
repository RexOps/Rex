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
use Rex::Helper::SSH2;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(run);

sub run {
   my $cmd = shift;

   my @ret = ();
   my $out;
   if(my $ssh = Rex::is_ssh()) {
      $out = net_ssh2_exec($ssh, $cmd);
      print $out;
   } else {
      $out = qx{$cmd};
   }
   return $out;
}

1;
