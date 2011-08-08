#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Sysctl - Manipulate sysctl

=head1 DESCRIPTION

With this module you can set and get sysctl parameters.

=head1 SYNOPSIS

 use Rex::Commands::Sysctl;
 
 my $data = sysctl "net.ipv4.tcp_keepalive_time";
 sysctl "net.ipv4.tcp_keepalive_time" => 1800;

=head1 EXPORTED FUNCTIONS

=over 4

=cut


package Rex::Commands::Sysctl;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sysctl);

=item sysctl($key [, $val])

This function will read the sysctl key $key.

If $val is given, then this function will set the sysctl key $key.

 task "tune", "server01", sub {
    if( sysctl("net.ipv4.ip_forward") == 0 ) {
       sysctl "net.ipv4.ip_forward" => 1;
    }
 };

=cut

sub sysctl {

   my ($key, $val) = @_;

   if($val) {

      Rex::Logger::debug("Setting sysctl key $key to $val");
      my $ret = run "/sbin/sysctl -n $key";

      if($ret ne $val) {
         run "/sbin/sysctl -w $key=$val";
         if($? != 0) {
            die("Sysctl failed $key -> $val");
         }
      }
      else {
         Rex::Logger::debug("$key has already value $val");
      }

   }
   else {
   
      my $ret = run "/sbin/sysctl -n $key";
      if($? == 0) {
         return $ret;
      }
      else {
         Rex::Logger::info("Error getting sysctl key: $key");
         die("Error getting sysctl key: $key");
      }

   }

}

=back

=cut

1;
