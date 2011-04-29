#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Upload

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

require Exporter;
use File::Basename qw(basename);
use Rex::Commands::Fs;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(upload);

=begin

=item upload($local, $remote)

Perform an upload. If $remote is a directory the file will be uploaded to that directory.

 task "upload", "remoteserver", sub {
    upload "localfile", "/path";
 };

=cut

sub upload {
   my $local = shift;
   my $remote = shift;

   unless($remote) {
      $remote = basename($local);
   }

   if(! -f $local) {
      Rex::Logger::info("File Not Found: $local");
      return 1;
   }

   if(my $ssh = Rex::is_ssh()) {
      Rex::Logger::info("Uploadling $local -> $remote");
      if(is_dir($remote)) {
         $remote = $remote . '/' . basename($local);
      }

      unless($ssh->scp_put($local, $remote)) {
         Rex::Logger::debug("upload: $remote is not writable");
         die("upload: $remote is not writable.");
      }
   } else {
      if(-d $remote) {
         $remote = $remote . '/' . basename($remote);
      }
      unless(system("cp $local $remote")) {
         Rex::Logger::debug("upload: $remote is not writable");
         die("upload: $remote is not writable.");
      }
   }
}

=begin

=back

=cut


1;
