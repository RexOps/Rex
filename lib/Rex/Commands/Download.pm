#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Download - Download remote files

=head1 DESCRIPTION

With this module you can download a remotefile via sftp, http and ftp from a host to your local computer.

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

=over 4

=cut

package Rex::Commands::Download;

use strict;
use warnings;

use vars qw($has_wget $has_curl $has_lwp);

# check which download type we should use
BEGIN {

   system("which wget >/dev/null 2>&1");
   $has_wget = !$?;

   system("which curl >/dev/null 2>&1");
   $has_curl = !$?;

   eval {
      require LWP::Simple;
      LWP::Simple->import;
      $has_lwp = 1;
   };

};

require Exporter;

use vars qw(@EXPORT);
use base qw(Exporter);

use Rex::Commands::Fs;
use File::Basename qw(basename);

@EXPORT = qw(download);

=item download($remote, [$local])

Perform a download. If no local file is specified it will download the file to the current directory.

 task "download", "remoteserver", sub {
    download "/remote/file", "localfile";
 };

 task "download", sub {
    download "http://www.rexify.org/index.html", "localfile.html";
 };

=cut

sub download {
   my $remote = shift;
   my $local = shift;

   if($remote =~ m/^(https?|ftp):\/\//) {
      _http_download($remote, $local);
   }
   else {
      _sftp_download($remote, $local);
   }
}

sub _sftp_download {
   my $remote = shift;
   my $local = shift;

   Rex::Logger::debug("Downloading via SFTP");
   unless($local) {
      $local = basename($remote);
   }
   Rex::Logger::debug("saving file to $local");

   unless(is_file($remote)) {
      Rex::Logger::info("File $remote not found");
      die("$remote not found.");
   }
   
   unless(is_readable($remote)) {
      Rex::Logger::info("File $remote is not readable.");
      die("$remote is not readable.");
   }

   if(my $ssh = Rex::is_ssh()) {
      if(-d $local) {
         $local = $local . '/' . basename($remote);
      }
      Rex::Logger::debug("Downloading $remote -> $local");

      $ssh->scp_get($remote, $local);
   } else {
      Rex::Logger::debug("Copying $remote -> $local");
      system("cp $remote $local");
   }

}

sub _http_download {
   my ($remote, $local) = @_;

   unless($local) {
      $local = basename($remote);
   }
   Rex::Logger::debug("saving file to $local");

   my $content = _get_http($remote);
   open(my $fh, ">", $local) or die($!);
   binmode $fh;
   print $fh $content;
   close($fh);
}

sub _get_http {
   my ($url) = @_;

   my $html;
   if($has_curl) {
      Rex::Logger::debug("Downloading via curl");
      $html = qx{curl -# -L '$url' 2>/dev/null};
   }
   elsif($has_wget) {
      Rex::Logger::debug("Downloading via wget");
      $html = qx{wget --no-check-certificate -O - '$url' 2>/dev/null};
   }
   elsif($has_lwp) {
      Rex::Logger::debug("Downloading via LWP::Simple");
      $html = get($url);
   }
   else {
      die("No tool found to download something. (curl, wget, LWP::Simple)");
   }

   return $html;
}

=back

=cut


1;
