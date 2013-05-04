#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Helper::Run;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Commands::Run;
use Rex::Interface::File;
use Rex::Interface::Fs;
require Rex::Commands;

@EXPORT = qw(upload_and_run);

sub upload_and_run {
   my ($template, %option) = @_;

   my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".tmp";

   my $fh = Rex::Interface::File->create;
   $fh->open(">", $rnd_file);
   $fh->write($template);
   $fh->close;

   my $fs = Rex::Interface::Fs->create;
   $fs->chmod(755, $rnd_file);

   my @argv;
   my $command = $rnd_file;

   if(exists $option{with}) {
      $command = $option{with} . " $command";
   }

   if(exists $option{args}) {
      $command .= join(" ", @{ $option{args} });
   }

   return run "$command 2>&1";
}

1;
