#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Host - Edit /etc/hosts

=head1 DESCRIPTION

With this module you can manage the host entries in /etc/hosts.

=head1 SYNOPSIS

 task "create-host", "remoteserver", sub {
   create_host "rexify.org" => {
    ip    => "88.198.93.110",
    aliases => ["www.rexify.org"],
   };
 };

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Host;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Commands::MD5;
use Rex::Logger;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(create_host get_host delete_host host_entry);

=head2 host_entry($name, %option)

Manages the entries in /etc/hosts.

 host_entry "rexify.org",
   ensure    => "present",
   ip        => "88.198.93.110",
   aliases   => ["www.rexify.org"],
   on_change => sub { say "added host entry"; };
 
  host_entry "rexify.org",
    ensure    => "absent",
    on_change => sub { say "removed host entry"; };

=cut

sub host_entry {
  my ( $res_name, %option ) = @_;

  $option{ensure} ||= "present";

  my $name = $res_name;
  if ( exists $option{host} ) {
    $name = $option{host};
  }

  my $file = "/etc/hosts";

  if ( exists $option{file} ) {
    $file = $option{file};
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_start( type => "host_entry", name => $res_name );

  my $old_md5 = md5($file);
  if ( $option{ensure} eq "present" ) {
    &create_host( $name, \%option );
  }
  else {
    &delete_host($name);
  }
  my $new_md5 = md5($file);

  if ( $new_md5 ne $old_md5 ) {
    if ( exists $option{on_change} && ref $option{on_change} eq "CODE" ) {
      $option{on_change}->( $name, %option );
    }

    Rex::get_current_connection()->{reporter}->report(
      changed => 1,
      message => "Resource host_entry changed to $option{ensure}"
    );
  }

  Rex::get_current_connection()->{reporter}
    ->report_resource_end( type => "host_entry", name => $res_name );
}

=head2 create_host($)

Update or create a /etc/hosts entry.

 create_host "rexify.org", {
   ip    => "88.198.93.110",
   aliases => ["www.rexify.org", ...]
 };

=cut

sub create_host {
  my ( $host, $data ) = @_;

  if ( !defined $data->{"ip"} ) {
    Rex::Logger::info("You need to set an ip for $host");
    die("You need to set an ip for $host");
  }

  $data->{file} ||= "/etc/hosts";

  Rex::Logger::debug("Creating host $host");

  my @cur_host = get_host( $host, { file => $data->{file} } );
  if ( !@cur_host ) {
    my $fh = file_append $data->{file};
    $fh->write( $data->{"ip"} . "\t" . $host );
    if ( exists $data->{"aliases"} ) {
      $fh->write( " " . join( " ", @{ $data->{"aliases"} } ) );
    }
    $fh->write("\n");
    $fh->close;
  }
  else {
    if ( $data->{"ip"} eq $cur_host[0]->{"ip"}
      && join( " ", @{ $data->{"aliases"} || [] } ) eq
      join( " ", @{ $cur_host[0]->{"aliases"} } ) )
    {

      Rex::Logger::debug("Nothing to update for host $host");
      return;

    }
    Rex::Logger::debug("Host already exists. Updating...");

    delete_host( $host, $data->{file} );
    return create_host(@_);
  }
}

=head2 delete_host($host)

Delete a host from /etc/hosts.

 delete_host "www.rexify.org";

=cut

sub delete_host {
  my ( $host, $file ) = @_;

  Rex::Logger::debug("Deleting host $host");
  $file ||= "/etc/hosts";

  if ( get_host( $host, { file => $file } ) ) {
    my $fh      = file_read $file;
    my @content = $fh->read_all;
    $fh->close;

    my @new_content = grep { !/\s\Q$host\E\b/ } @content;

    $fh = file_write $file;
    $fh->write(@new_content);
    $fh->close;
  }
  else {
    Rex::Logger::debug("Host does not exists.");
  }
}

=head2 get_host($host)

Returns the information of $host in /etc/hosts.

 my @host_info = get_host "localhost";
 say "Host-IP: " . $host_info[0]->{"ip"};

=cut

sub get_host {
  my ( $hostname, @lines ) = @_;

  Rex::Logger::debug("Getting host ($hostname) information");

  my $file = "/etc/hosts";

  my @content;
  if ( @lines && !ref $lines[0] ) {
    @content = @lines;
  }
  else {
    if ( ref $lines[0] eq "HASH" ) {
      $file = $lines[0]->{file};
    }
    my $fh = file_read $file;
    @content = $fh->read_all;
    $fh->close;
  }

  my @hosts = _parse_hosts(@content);
  my @ret;
  for my $item (@hosts) {
    if ( $item->{host} eq $hostname ) {
      push @ret, $item;
    }
    else {
      push @ret, $item if ( grep { $_ eq $hostname } @{ $item->{aliases} } );
    }
  }

  return @ret;
}

sub _parse_hosts {
  my (@lines) = @_;

  my @ret;

  for my $line (@lines) {
    chomp $line;
    next if ( $line =~ m/^#/ );
    next if ( !$line );
    next if ( $line =~ m/^\s*$/ );

    my ( $ip, $_host, @aliases ) = split( /\s+/, $line );

    push @ret,
      {
      ip      => $ip,
      host    => $_host,
      aliases => \@aliases,
      };

  }

  return @ret;
}

1;
