#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Virtualization::Docker::start;

use strict;
use warnings;

use Rex::Logger;
use Rex::Helper::Run;

sub execute {
   my ($class, %opt) = @_;

   my $bind = $opt{bind} // '0.0.0.0';
   my $host = $opt{host} // 'unix:///var/run/docker.sock';

   Rex::Logger::debug("starting docker daemon");

   i_run "docker -d -H $host -ip $bind";
   if($? != 0) {
      die("Error starting docker daemon");
   }

}

1;


