#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::MD5 - Calculate MD5 sum of files

=head1 DESCRIPTION

With this module you calculate the md5 sum of a file.

=head1 SYNOPSIS

 my $md5 = md5($file);

=head1 EXPORTED FUNCTIONS

=over 4

=cut



package Rex::Commands::MD5;

use strict;
use warnings;

use Rex::Logger;
require Rex::Commands;
use Rex::Interface::Exec;
use Rex::Interface::File;
use Rex::Interface::Fs;


require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(md5);

=item md5($file)

This function will return the md5 sum (hexadecimal) for the given file.

 task "md5", "server01", sub {
    my $md5 = md5("/etc/passwd");
 };

=cut

sub md5 {
   my ($file) = @_;

   if(is_file($file)) {

      Rex::Logger::debug("Calculating Checksum (md5) of $file");

      my $script = q|
      use Digest::MD5;
      print Digest::MD5::md5_hex(<>) . "\n";
      |;

      my $rnd_file = "/tmp/" . Rex::Commands::get_random(8, 'a' .. 'z') . ".tmp";
      my $fh = Rex::Interface::File->create;
      $fh->open(">", $rnd_file);
      $fh->write($script);
      $fh->close;

      my $exec = Rex::Interface::Exec->create;
      my $md5 = $exec->exec("perl $rnd_file $file");

      unless($? == 0) {
         $md5 = $exec->exec("md5sum $file");
      }

      unless($? == 0) {
         Rex::Logger::info("Unable to get md5 sum of $file");
         die("Unable to get md5 sum of $file");
      }

      Rex::Interface::Fs->create->unlink($rnd_file);

      Rex::Logger::debug("MD5SUM ($file): $md5");
      return $md5;
   
   }
   else {
      
      Rex::Logger::debug("File $file not found.");
      die("File $file not found");

   }
}

=back

=cut

1;
