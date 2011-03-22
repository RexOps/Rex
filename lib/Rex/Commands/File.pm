#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

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

sub file_write {
   my ($file) = @_;
   my $fh;
   if(my $ssh = Rex::is_ssh()) {
      $fh = $ssh->sftp->open($file, O_WRONLY | O_CREAT);
   } else {
      open($fh, ">", $file) or die($!);
   }

   unless($fh) {
      die("Can't open $file for writing.");
   }

   return Rex::FS::File->new(fh => $fh);
}

sub file_read {
   my ($file) = @_;
   my $fh;
   if(my $ssh = Rex::is_ssh()) {
      $fh = $ssh->sftp->open($file, O_RDONLY);
   } else {
      open($fh, "<", $file) or die($!);
   }

   unless($fh) {
      die("Can't open $file for reading.");
   }

   return Rex::FS::File->new(fh => $fh);
}

1;
