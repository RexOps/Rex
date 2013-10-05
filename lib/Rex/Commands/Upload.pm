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
use Rex::Hook;

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw(upload);

=item upload($local, $remote)

Perform an upload. If $remote is a directory the file will be uploaded to that directory.

 task "upload", "remoteserver", sub {
    upload "localfile", "/path";
 };


This function supports the following hooks:

=over 8 

=item before

This gets executed before everything is done. The return value of this hook overwrite the original parameters of the function-call.

=item before_change

This gets executed right before the new file is written.

=item after_change

This gets executed right after the file was written.

=item after

This gets executed right before the upload() function returns.

=back


=cut

sub upload {

   #### check and run before hook
   eval {
      my @new_args = Rex::Hook::run_hook(upload => "before", @_);
      if(@new_args) {
         @_ = @new_args;
      }
      1;
   } or do {
      die("Before-Hook failed. Canceling upload() action: $@");
   };
   ##############################

   my ($local, $remote) = @_;


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

   my $__ret;

   if($local_md5 && $remote_md5 && $local_md5 eq $remote_md5) {
      Rex::Logger::debug("local md5 and remote md5 are the same: $local_md5 eq $remote_md5. Not uploading.");
      if(Rex::Config->get_do_reporting) {
         $__ret = {changed => 0, ret => 0};
      }
   }
   else {

      Rex::Logger::debug("Uploading: $local to $remote");

      #### check and run before_change hook
      Rex::Hook::run_hook(upload => "before_change", @_);
      ##############################

      $__ret = $fs->upload($local, $remote);

      #### check and run after_change hook
      Rex::Hook::run_hook(upload => "after_change", @_, $__ret);
      ##############################

      if(Rex::Config->get_do_reporting) {
         $__ret = {changed => 1, ret => $__ret };
      }

   }

   #### check and run before hook
   Rex::Hook::run_hook(upload => "after", @_, $__ret);
   ##############################

   return $ret;
}

=back

=cut


1;
