#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Host - Edit /etc/hosts

=head1 DESCRIPTION

With this module you can manage the host entries in /etc/hosts.

=head1 SYNOPSIS

 task "create-host", "remoteserver", sub {
    create_host "rexify.org" => {
      ip      => "88.198.93.110",
      aliases => ["www.rexify.org"],
    };
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Host;

use strict;
use warnings;

require Rex::Exporter;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Logger;
use Data::Dumper;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(create_host get_host delete_host);

=item create_host($)

Update or create a /etc/hosts entry.

 create_host "rexify.org", {
    ip      => "88.198.93.110",
    aliases => ["www.rexify.org", ...]
 };

=cut

sub create_host {
   my ($host, $data) = @_;

   if(! defined $data->{"ip"}) {
      Rex::Logger::info("You need to set an ip for $host");
      die("You need to set an ip for $host");
   }

   Rex::Logger::debug("Creating host $host");

   my @cur_host = get_host($host);
   if(! @cur_host) {
      my $fh = file_append "/etc/hosts";
      $fh->write($data->{"ip"} . "\t" . $host);
      if(exists $data->{"aliases"}) {
         $fh->write(" " . join(" ", @{$data->{"aliases"}}));
      }
      $fh->write("\n");
      $fh->close;
   }
   else {
      my @host = get_host($host);
      if($data->{"ip"} eq $host[0]->{"ip"} 
         && join(" ", @{$data->{"aliases"}}) eq join(" ", @{$host[0]->{"aliases"}})) {

         Rex::Logger::debug("Nothing to update for host $host");
         return;

      }
      Rex::Logger::debug("Host already exists. Updating...");

      delete_host($host);
      return create_host(@_);
   }
}

=item delete_host($host)

Delete a host from /etc/hosts.

 delete_host "www.rexify.org";

=cut

sub delete_host {
   my ($host) = @_;

   Rex::Logger::debug("Deleting host $host");

   if(get_host($host)) {
      my $fh = file_read "/etc/hosts";
      my @content = $fh->read_all;
      $fh->close;

      my @new_content = grep { ! /\s$host\s?/ } @content;

      $fh = file_write "/etc/hosts";
      $fh->write(@new_content);
      $fh->close;
   }
   else {
      Rex::Logger::debug("Host does not exists.");
   }
}

=item get_host($host)

Returns the information of $host in /etc/resolv.conf.

 my @host_info = get_host "localhost";
 say "Host-IP: " . $host_info[0]->{"ip"};

=cut

sub get_host {
   my ($hostname, @lines) = @_;

   Rex::Logger::debug("Getting host ($hostname) information");

   my @content;
   if(@lines) {
      @content = @lines;
   }
   else {
      my $fh = file_read "/etc/hosts";
      @content = $fh->read_all;
      $fh->close;
   }

   my @hosts = _parse_hosts(@content);
   my @ret;
   for my $item (@hosts) {
      if($item->{host} eq $hostname) {
         push @ret, $item;
      }
      else {
         push @ret, $item if(grep { $_ eq $hostname } @{$item->{aliases}});
      }
   }

   return @ret;
}

sub _parse_hosts {
   my (@lines) = @_;
   
   my @ret;

   for my $line (@lines) {
      chomp $line;
      next if($line =~ m/^#/);
      next if(! $line);
      next if($line =~ m/^\s*$/);

      my ($ip, $_host, @aliases) = split(/\s+/, $line);

      push @ret, { ip => $ip,
         host => $_host,
         aliases => \@aliases,
      };

   }

   return @ret;
}

=back

=cut

1;
