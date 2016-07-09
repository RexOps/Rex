#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Sysctl - Manipulate sysctl

=head1 DESCRIPTION

With this module you can set and get sysctl parameters.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

This function doesn't persist the entries in /etc/sysctl.conf.

=head1 SYNOPSIS

 use Rex::Commands::Sysctl;
 
 my $data = sysctl "net.ipv4.tcp_keepalive_time";
 sysctl "net.ipv4.tcp_keepalive_time" => 1800;

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Sysctl;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Helper::Run;
use Rex::Commands::File;

require Rex::Exporter;

use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(sysctl);

=head2 sysctl($key [, $val [, %options]])

This function will read the sysctl key $key.

If $val is given, then this function will set the sysctl key $key.

 task "tune", "server01", sub {
   if( sysctl("net.ipv4.ip_forward") == 0 ) {
     sysctl "net.ipv4.ip_forward" => 1;
   }
 };

If both $val and option persistent => "true" are passed the sysctl key and value are stored in /etc/sysctl.conf.
If the key already exists in the file, it will be updated to the new value.

 task "forwarding", "server01", sub {
   sysctl "net.ipv4.ip_forward" => 1, persistent => "true";
 }

=cut

sub sysctl_save {
  my ( $key, $value ) = @_;
  append_or_amend_line "/etc/sysctl.conf",
    line   => "$key=$value",
    regexp => qr{\Q$key=};
}

sub sysctl {

  my ( $key, $val, %options ) = @_;

  if ( defined $val ) {

    Rex::Logger::debug("Setting sysctl key $key to $val");
    my $ret = i_run "/sbin/sysctl -n $key";

    if ( $ret ne $val ) {
      i_run "/sbin/sysctl -w $key=$val";
      if ( $? != 0 ) {
        die("Sysctl failed $key -> $val");
      }
    }
    else {
      Rex::Logger::debug("$key has already value $val");
    }

    if ( defined %options ) {
      if ( exists $options{persistent} && $options{persistent} eq "true" ) {
        Rex::Logger::debug("Writing $key=$val to sysctl.conf");
        sysctl_save $key, $val;
      }
    }

  }
  else {

    my $ret = i_run "/sbin/sysctl -n $key";
    if ( $? == 0 ) {
      return $ret;
    }
    else {
      Rex::Logger::info( "Error getting sysctl key: $key", "warn" );
      die("Error getting sysctl key: $key");
    }

  }

}

1;
