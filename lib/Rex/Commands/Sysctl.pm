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
use Rex::Commands::Run;
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

If both $val and ensure option are used, the sysctl key is modified and the value may persist in /etc/sysctl.conf depending if ensure option is "present" or "absent".

With ensure => "present", if the key already exists in the file, it will be updated to the new value.

 task "forwarding", "server01", sub {
   sysctl "net.ipv4.ip_forward" => 1, ensure => "present";
 }

=cut

sub sysctl_save {
  my ( $key, $value ) = @_;
  my $sysctl = get_sysctl_command();

  append_or_amend_line "/etc/sysctl.conf",
    line      => "$key=$value",
    regexp    => qr{\Q$key=},
    on_change => sub { i_run "$sysctl -p" };
}

sub sysctl_remove {
  my ( $key, $value ) = @_;
  my $sysctl = get_sysctl_command();

  delete_lines_according_to "$key=$value", "/etc/sysctl.conf",
    on_change => sub { i_run "$sysctl -p" };
}

sub sysctl {

  my ( $key, $val, %options ) = @_;
  my $sysctl = get_sysctl_command();

  if ( defined $val ) {

    Rex::Logger::debug("Setting sysctl key $key to $val");
    my $ret = i_run "$sysctl -n $key";

    if ( $ret ne $val ) {
      i_run "$sysctl -w $key=$val", fail_ok => 1;
      if ( $? != 0 ) {
        die("Sysctl failed $key -> $val");
      }
    }
    else {
      Rex::Logger::debug("$key has already value $val");
    }

    if ( $options{ensure} || $options{persistent} ) {
      if ( $options{ensure} eq "present" ) {
        Rex::Logger::debug("Writing $key=$val to sysctl.conf");
        sysctl_save $key, $val;
      }
      elsif ( $options{ensure} eq "absent" ) {
        Rex::Logger::debug("Removing $key=$val of sysctl.conf");
        sysctl_remove $key, $val;
      }
      else {
        Rex::Logger::info(
          "Error : " . $options{ensure} . " is not a known ensure parameter" );
      }
    }

  }
  else {

    my $ret = i_run "$sysctl -n $key", fail_ok => 1;
    if ( $? == 0 ) {
      return $ret;
    }
    else {
      Rex::Logger::info( "Error getting sysctl key: $key", "warn" );
      die("Error getting sysctl key: $key");
    }

  }

}

sub get_sysctl_command {
  my $sysctl = can_run( '/sbin/sysctl', '/usr/sbin/sysctl' );

  if ( !defined $sysctl ) {
    my $message = q(Couldn't find sysctl executable);
    Rex::Logger::info( $message, 'error' );
    die($message);
  }

  return $sysctl;
}

1;
