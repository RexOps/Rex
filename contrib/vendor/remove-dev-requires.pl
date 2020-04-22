#!perl
use strict;
use warnings;

# This script is to remove various entries from dist.ini
# for gentoo purposes.
#
# Primarily, it removes entries from the DevelopRequires Prereqs
# section, and if only blacklisted entries are found, removes the whole section
#
# usage: perl contrib/vendor/gentoo-dev-requires.pl Test::Kwalitee Test::PerlTidy dist.ini

use File::Spec::Functions qw( splitpath catpath );

exit usage() if grep /\A-(h|H|-help|\?)/, @ARGV;

my $section = '[Prereqs / DevelopRequires]';
my $file =
  ( @ARGV > 0 ? pop @ARGV : die usage_err("Missing argument for 'FILE'") );
my $out = do {
  my (@path) = splitpath($file);
  my (@out)  = @path;
  $out[-1] = "._tmp_" . $path[-1] . "." . $$;
  catpath(@out);
};
my (@blacklisted) =
  ( @ARGV > 0 ? @ARGV : die usage_err("Missing argument for 'DEP'") );
my (%removed);

open my $src,  '<', $file or die "Can't open $file for read, $!";
open my $dest, '>', $out  or die "Can't open $out for write, $!";

my $seen = 0;

main_loop: while ( my $line = <$src> ) {
  if ( $line !~ /^\Q$section\E/ ) {
    $dest->print($line);
    next main_loop;
  }
  $seen++;

  # Stash plugin heading for later
  my $heading       = $line;
  my $needs_section = 0;
plugin_loop: while ( my $section_line = <$src> ) {
    for my $blacklisted (@blacklisted) {
      $removed{$blacklisted} = 0 unless exists $removed{$blacklisted};
      if ( $section_line =~ /^\Q$blacklisted\E\s*=/ ) {
        STDERR->print("Removing $section -> $section_line");
        $removed{$blacklisted}++;
        next plugin_loop;
      }
    }
    if ( $section_line =~ /^\s*$/ ) {
      if ($needs_section) {

        # keep blank lines if we keep the section
        $dest->print($_);
      }
      else {
        next plugin_loop;
      }
    }

    # Abort parsing on the first plugin section after this one
    if ( $section_line =~ /^\[/ ) {
      if ( not $needs_section ) {
        STDERR->print("Removed section $section\n");
      }

      # forget we saw this line and reinject it into the main loop
      $line = $section_line;
      redo main_loop;
    }

    # Line is a non-blacklisted, section is needed
    # So we need this section
    if ( not $needs_section ) {
      $dest->print($heading);
      $needs_section = 1;
    }
    $dest->print($section_line);
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
if ( my (@unremoved) = grep { $removed{$_} == 0 } keys %removed ) {
  unlink $out or warn "Can't cleanup temp file $out, $!";
  die "No dependencies [@unremoved] in $file section $section";
}
if ( my (@multimatch) = grep { $removed{$_} > 1 } keys %removed ) {
  warn "Multiple definitions of dependencies [@multimatch], probably a bug";
}
rename $out, $file or die "Failed to rename $out to $file, $!";

exit 0;

sub usage {
  STDERR->print("perl $0 DEP [DEP...] FILE\n");
  STDERR->print("\n");
  STDERR->print("\tDEP\tname of development dependency to remove\n");
  STDERR->print("\tFILE\tname of file to remove dependencies from\n");
  1;
}

sub usage_err {
  my ($message) = @_;
  STDERR->print("$message\n\n") if defined $message;
  usage();
  "$message";
}
