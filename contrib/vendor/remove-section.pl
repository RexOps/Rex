#!perl
use strict;
use warnings;

# This tool implements a quick hack to strip a given section from
# a dzil dist.ini
#
# Its slightly complicated vs the easy "sed -i " alternative, but
# it allows more granular control, in particular, the ability to fail
# when no changes are made
#
# And it has slightly more controlled 'in-place editing', using
# ._tmp_dist.ini.<PID> and only doing the final replace
# when changes are actually needed, and can be done without error
#
# Usage:
#   perl contrib/vendor/remove-section Test::Kwalitee dist.ini
#
use File::Spec::Functions qw( splitpath catpath );

exit usage() if grep /\A-(h|H|-help|\?)/, @ARGV;

my $section =
  ( $ARGV[0] ? $ARGV[0] : die usage_err("Missing argument for 'SECTION'") );
my $file =
  ( $ARGV[1] ? $ARGV[1] : die usage_err("Missing argument for 'FILE'") );

my $out = do {
  my (@path) = splitpath($file);
  my (@out)  = @path;
  $out[-1] = "._tmp_" . $path[-1] . "." . $$;
  catpath(@out);
};

STDERR->print("Removing section '$section' from '$file'\n");

open my $src,  '<', $file or die "Can't open $file for read, $!";
open my $dest, '>', $out  or die "Can't open $out for write, $!";

my $seen = 0;

section_scan: while ( my $line = <$src> ) {
  if ( $line !~ /\A\s*\[\Q$section\E\]\s*\z/ ) {
    $dest->print($line);
    next;
  }
  $seen++;
  while ( my $section_line = <$src> ) {
    if ( $section_line =~ /\A\s*\[/ ) {

      # this basically works like an 'unread' of <$src>
      # so when a new section start appears, the current section is considred
      # finished and the main loop resumes.
      #
      # This means it can strip the same section occurring twice in a row
      # without barbaric code
      $line = $section_line;
      redo section_scan;
    }
  }
}
close $src  or warn "Error closing input file $file, $!";
close $dest or die "Error closing output file $out, $!";

if ( $seen > 1 ) {
  warn "Multiple sections stripped named $section, probably a bug";
}
if ( $seen < 1 ) {
  unlink $out or warn "Can't cleanup temp file $out, $!";
  die "No section named '$section' found in $file";
}
rename $out, $file or die "Failed to rename $out to $file, $!";

exit 0;

sub usage {
  STDERR->print("perl $0 SECTION FILE\n");
  STDERR->print("\n");
  STDERR->print("\tSECTION\tname of section to remove\n");
  STDERR->print("\tFILE\tname of file to remove section from\n");
  1;
}

sub usage_err {
  my ($message) = @_;
  STDERR->print("$message\n\n") if defined $message;
  usage();
  "$message";
}
