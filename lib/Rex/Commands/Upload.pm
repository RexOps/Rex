#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Upload - Upload a local file to a remote server

=head1 DESCRIPTION

With this module you can upload a local file via sftp to a remote host.

=head1 SYNOPSIS

 task "upload", "remoteserver", sub {
    upload "localfile", "/remote/file";
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::Upload;

use strict;
use warnings;

require Rex::Exporter;
use File::Basename qw(basename);
use Rex::Config;
use Rex::Commands::Fs;
use Rex::Interface::Fs;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(upload);

=item upload($local, $remote)

Perform an upload. If $remote is a directory the file will be uploaded to that directory.

 task "upload", "remoteserver", sub {
    upload "localfile", "/path";
 };

=cut

sub upload {
   my $local = shift;
   my $remote = shift;


   my $fs = Rex::Interface::Fs->create;

   # if remote not set, use name of local.
   # must be done before the next line.
   unless($remote) {
      $remote = basename($local);
   }

   # if there is a file called filename.environment then use this file
   # ex: 
   # upload "files/hosts", "/etc/hosts";
   # 
   # rex -E live ...
   # will first look if files/hosts.live is available, if not it will
   # use files/hosts

   my $old_local = $local; # for the upload location use the given name

   if(-f "$local." . Rex::Config->get_environment) {
      $local = "$local." . Rex::Config->get_environment;
   }

   if(! -f $local) {
      Rex::Logger::info("File Not Found: $local");
      die("File $local not found.");
   }

   if(is_dir($remote)) {
      $remote = $remote . '/' . basename($old_local);
   }
   $fs->upload($local, $remote);
}

=back

=cut


1;
