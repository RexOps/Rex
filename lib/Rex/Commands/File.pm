#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::File

=head1 DESCRIPTION

With this module you can manipulate files.

=head1 SYNOPSIS

 task "read-passwd", "server01", sub {
    my $fh = file_read "/etc/passwd";
    say $fh->read_all;
    $fh->close;
 };
 
 task "write-passwd", "server01", sub {
    my $fh = file_write "/etc/passwd";
    $fh->write("root:*:0:0:root user:/root:/bin/sh\n");
    $fh->close;
 };

=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::File;

use strict;
use warnings;
use Fcntl;

require Exporter;
use Data::Dumper;
use Rex::FS::File;

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw(file_write file_close file_read);

use vars qw(%file_handles);

=begin

=item file_write($file_name)

This function opens a file for writing (it will truncate the file if it already exists). It returns a Rex::FS::File object on success.

On failure it will die.

 my $fh;
 eval {
    $fh = file_write("/etc/groups");
 };
 
 # catch an error
 if($@) {
    print "An error occured. $@.\n";
    exit;
 }
 
 # work with the filehandle
 $fh->write("...");
 $fh->close;

=cut

sub file_write {
   my ($file) = @_;
   my $fh;

   Rex::Logger::debug("Opening file: $file for writing.");

   if(my $ssh = Rex::is_ssh()) {
      $fh = $ssh->sftp->open($file, O_WRONLY | O_CREAT | O_TRUNC );
   } else {
      open($fh, ">", $file) or die($!);
   }

   unless($fh) {
      Rex::Logger::debug("Can't open $file for writing.");
      die("Can't open $file for writing.");
   }

   return Rex::FS::File->new(fh => $fh);
}

=begin

=item file_read($file_name)

This function opens a file for reading. It returns a Rex::FS::File object on success.

On failure it will die.

 my $fh;
 eval {
    $fh = read("/etc/groups");
 };
 
 # catch an error
 if($@) {
    print "An error occured. $@.\n";
    exit;
 }
 
 # work with the filehandle
 my $content = $fh->read_all;
 $fh->close;

=cut

sub file_read {
   my ($file) = @_;
   my $fh;

   Rex::Logger::debug("Opening file: $file for reading.");

   if(my $ssh = Rex::is_ssh()) {
      $fh = $ssh->sftp->open($file, O_RDONLY);
   } else {
      open($fh, "<", $file) or die($!);
   }

   unless($fh) {
      Rex::Logger::debug("Can't open $file for reading.");
      die("Can't open $file for reading.");
   }

   return Rex::FS::File->new(fh => $fh);
}

=begin

=back

=cut

1;
