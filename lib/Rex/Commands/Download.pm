#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Download - Download remote files

=head1 DESCRIPTION

With this module you can download a remotefile via sftp, http and ftp from a host to your local computer.

Version <= 1.0: All these functions will not be reported.

=head1 SYNOPSIS

 # sftp
 task "download", "remoteserver", sub {
   download "/remote/file", "localfile";
 };
 
 # http
 task "download2", sub {
   download "http://server/remote/file";
 };


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Download;

use strict;
use warnings;
use Rex::Helper::UserAgent;
use Carp;

# VERSION

use vars qw($has_wget $has_curl $has_lwp);

# check which download type we should use
BEGIN {

  if ( $^O !~ m/^MSWin/ ) {
    system("which wget >/dev/null 2>&1");
    $has_wget = !$?;

    system("which curl >/dev/null 2>&1");
    $has_curl = !$?;
  }

  eval {
    require Rex::Helper::UserAgent;
    $has_lwp = 1;
  };

  if ( $^O =~ m/^MSWin/ && !$has_lwp ) {
    Rex::Logger::info("Please install LWP::UserAgent to allow file downloads.");
  }

}

require Rex::Exporter;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

use Rex::Commands::Fs;
use Rex::Helper::Path;
use Rex::Interface::Fs;
use File::Basename qw(basename);

@EXPORT = qw(download);

=head2 download($remote, [$local])

Perform a download. If no local file is specified it will download the file to the current directory.

 task "download", "remoteserver", sub {
   download "/remote/file", "localfile";
 };
 
 task "download", sub {
   download "http://www.rexify.org/index.html", "localfile.html";
 };

=cut

sub download {
  my ( $remote, $local, %option ) = @_;

  unless ($local) {
    $local = basename($remote);
  }

  if ( -d $local ) {
    $local = $local . '/' . basename($remote);
  }

  Rex::Logger::debug("saving file to $local");
  $remote = resolv_path($remote);
  $local  = resolv_path( $local, 1 );

  if ( $remote =~ m/^(https?|ftp):\/\// ) {
    _http_download( $remote, $local, %option );
  }
  else {
    _sftp_download( $remote, $local, %option );
  }
}

sub _sftp_download {
  my $remote = shift;
  my $local  = shift;

  my $fs = Rex::Interface::Fs->create;

  Rex::Logger::debug("Downloading via SFTP");

  unless ( is_file($remote) ) {
    Rex::Logger::info("File $remote not found");
    die("$remote not found.");
  }

  unless ( is_readable($remote) ) {
    Rex::Logger::info("File $remote is not readable.");
    die("$remote is not readable.");
  }

  $fs->download( $remote, $local );

}

sub _http_download {
  my ( $remote, $local, %option ) = @_;

  my $content = _get_http( $remote, %option );

  open( my $fh, ">", $local ) or die($!);
  binmode $fh;
  print $fh $content;
  close($fh);
}

sub _get_http {
  my ( $url, %option ) = @_;

  my $html;
  if ($has_curl) {
    Rex::Logger::debug("Downloading via curl");
    if ( exists $option{user} && exists $option{password} ) {
      $html =
        qx{curl -u '$option{user}:$option{password}' -# -L -k '$url' 2>/dev/null};
    }
    else {
      $html = qx{curl -# -L -k '$url' 2>/dev/null};
    }
  }
  elsif ($has_wget) {
    Rex::Logger::debug("Downloading via wget");
    if ( exists $option{user} && exists $option{password} ) {
      $html =
        qx{wget --http-user=$option{user} '--http-password=$option{password}' --no-check-certificate -O - '$url' 2>/dev/null};
    }
    else {
      $html = qx{wget --no-check-certificate -O - '$url' 2>/dev/null};
    }
  }
  elsif ($has_lwp) {
    Rex::Logger::debug("Downloading via LWP::UserAgent");
    my $ua   = Rex::Helper::UserAgent->new;
    my $resp = $ua->get( $url, %option );
    if ( $resp->is_success ) {
      $html = $resp->content;
    }
    else {
      confess "Error downloading $url.";
    }
  }
  else {
    die("No tool found to download something. (curl, wget, LWP::Simple)");
  }

  return $html;
}

1;
