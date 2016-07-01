#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::MD5 - Calculate MD5 sum of files

=head1 DESCRIPTION

With this module you calculate the md5 sum of a file.

This is just a helper function and will not be reported.

=head1 SYNOPSIS

 use Rex::Commands::MD5;
 my $md5 = md5($file);

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::MD5;

use strict;
use warnings;

# VERSION

use Rex::Logger;
require Rex::Commands;
use Rex::Interface::Exec;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Helper::Path;
use Rex::Helper::Run;

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(md5);

=head2 md5($file)

This function will return the MD5 checksum (hexadecimal) for the given file.

 task "checksum", "server01", sub {
   say md5("/etc/passwd");
 };

=cut

sub md5 {
  my ($file) = @_;

  my $fs = Rex::Interface::Fs->create;
  return $fs->md5($file);

}

1;
