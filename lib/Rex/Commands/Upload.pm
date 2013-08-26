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
use Rex::Helper::Path;
use Rex::Commands::MD5;
use Rex::Commands;

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

   $local = Rex::Helper::Path::get_file_path($local, caller());

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

   # first get local md5
   my $local_md5;
   LOCAL {
      $local_md5 = md5($local);
   };

   if(! $local_md5) {
      die("Error getting local md5 sum of $local");
   }

   # than get remote md5 to test if we need to upload the file
   my $remote_md5 = "";
   eval {
      $remote_md5 = md5($remote);
   };

   if($local_md5 && $remote_md5 && $local_md5 eq $remote_md5) {
      Rex::Logger::debug("local md5 and remote md5 are the same: $local_md5 eq $remote_md5. Not uploading.");
      return {changed => 0};
   }

   Rex::Logger::debug("Uploading: $local to $remote");

   $fs->upload($local, $remote);

   return {changed => 1};
}

=back

=cut


1;
