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

 task "md5", "server01", sub {
   my $md5 = md5("/etc/passwd");
 };

=cut

sub md5 {
  my ($file) = @_;

  my $fs = Rex::Interface::Fs->create;

  if ( $fs->is_file($file) ) {
    Rex::Logger::debug("Calculating checksum (MD5) of $file");

    my $command =
      ( $^O =~ m/^MSWin/i && Rex::is_local() )
      ? qq(perl -MDigest::MD5 -e "open my \$fh, '<', \$ARGV[0] or die 'Cannot open ' . \$ARGV[0]; binmode \$fh; print Digest::MD5->new->addfile(\$fh)->hexdigest;" "$file")
      : qq(perl -MDigest::MD5 -e 'open my \$fh, "<", \$ARGV[0] or die "Cannot open " . \$ARGV[0]; binmode \$fh; print Digest::MD5->new->addfile(\$fh)->hexdigest;' '$file');

    my $md5 = i_run( $command, fail_ok => 1 );

    unless ( $? == 0 ) {

      my $exec = Rex::Interface::Exec->create;

      my $os = $exec->exec("uname -s");
      if ( $os =~ /bsd/i ) {
        $md5 = $exec->exec("/sbin/md5 -q '$file'");
      }
      else {
        ($md5) = split( /\s/, $exec->exec("md5sum '$file'") );
      }

      if ( !$md5 ) {
        my $message = "Unable to get MD5 checksum of $file: $!";
        Rex::Logger::info($message);
        die($message);
      }
    }

    chomp $md5;

    Rex::Logger::debug("MD5 checksum of $file: $md5");

    return $md5;
  }
  else {
    my $message = "File not found: $file";
    Rex::Logger::debug($message);
    die($message);
  }
}

1;
