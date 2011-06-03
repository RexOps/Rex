#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Download - Download files via SFTP

=head1 DESCRIPTION

With this module you can download a remotefile via sftp from a host to your local computer.

=head1 SYNOPSIS

 task "download", "remoteserver", sub {
    download "/remote/file", "localfile";
 };
 
 task "download2", "remoteserver", sub {
    download "/remote/file";
 };


=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Download;

use strict;
use warnings;

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

=cut

sub download {
   my $remote = shift;
   my $local = shift;

   unless($local) {
      $local = basename($remote);
   }

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
      Rex::Logger::info("Downloading $remote -> $local");

      $ssh->scp_get($remote, $local);
   } else {
      Rex::Logger::info("Copying $remote -> $local");
      system("cp $remote $local");
   }
}


=back

=cut


1;
