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

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;
require Rex::Commands;
require Rex::Commands::Run;
use Rex::Interface::Exec;
use Rex::Interface::File;
use Rex::Interface::Fs;
use Rex::Helper::Path;
use Rex::Helper::Run;
use English qw(-no_match_vars);

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

  if ( $fs->is_file($file) ) {
    Rex::Logger::debug("Calculating checksum (MD5) of $file");

    my $md5 = _digest_md5($file) // _binary_md5($file);

    if ( !$md5 ) {
      my $message = "Unable to get MD5 checksum of $file: $!";
      Rex::Logger::info($message);
      die($message);
    }

    Rex::Logger::debug("MD5 checksum of $file: $md5");

    return $md5;
  }
  else {
    my $message = "File not found: $file";
    Rex::Logger::debug($message);
    die($message);
  }
}

sub _digest_md5 {
  my $file = shift;
  my $md5;

  my $perl = Rex::is_local() ? $EXECUTABLE_NAME : 'perl';

  my $command =
    ( $^O =~ m/^MSWin/i && Rex::is_local() )
    ? qq("$perl" -MDigest::MD5 -e "open my \$fh, '<', \$ARGV[0] or die 'Cannot open ' . \$ARGV[0]; binmode \$fh; print Digest::MD5->new->addfile(\$fh)->hexdigest;" "$file")
    : qq('$perl' -MDigest::MD5 -e 'open my \$fh, "<", \$ARGV[0] or die "Cannot open " . \$ARGV[0]; binmode \$fh; print Digest::MD5->new->addfile(\$fh)->hexdigest;' '$file');

  my $result = i_run( $command, fail_ok => 1 );

  if ( $? == 0 ) {
    $md5 = $result;
  }

  return $md5;
}

sub _binary_md5 {
  my $file = shift;
  my $md5;

  my $exec = Rex::Interface::Exec->create;

  if ( Rex::Commands::Run::can_run('md5') ) {
    ($md5) = $exec->exec("md5 '$file'") =~ qr{\s+=\s+([a-f0-9]{32})\s*$};
  }
  elsif ( Rex::Commands::Run::can_run('md5sum') ) {
    ($md5) = $exec->exec("md5sum '$file'") =~ qr{^\\?([a-f0-9]{32})\s+};
  }

  return $md5;
}

1;
