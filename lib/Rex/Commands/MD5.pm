#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::MD5;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands::Run;
use Rex::Commands::Fs;


require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(md5);

sub md5 {
   my ($file) = @_;

   if(is_file($file)) {

      Rex::Logger::debug("Calculating Checksum (md5) of $file");
      my $md5 = run "perl -MDigest::MD5 -e 'print Digest::MD5::md5_hex(<>) . \"\\n\"' $file";

      unless($? == 0) {
         $md5 = run "md5sum $file";
      }

      unless($? == 0) {
         Rex::Logger::info("Unable to get md5 sum of $file");
         return;
      }

      Rex::Logger::debug("MD5SUM ($file): $md5");
      return $md5;
   
   }
   else {
      
      Rex::Logger::info("File $file not found.");

   }
}

1;
