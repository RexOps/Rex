#!/usr/bin/env perl

use v5.12.5;
use warnings;

open my $fh, "<", $ARGV[0] or die $!;
my @lines = <$fh>;
chomp @lines;
close $fh;

my $in_pod = 0;

my @new_file;

print "[+] sanitizing $ARGV[0]\n";

for ( my $i = 0 ; $i <= $#lines ; $i++ ) {
  my $prev_line = $lines[ $i - 1 ];
  my $next_line = $lines[ $i + 1 ];
  my $cur_line  = $lines[$i];

  if ( $cur_line =~ m/^=cut/ ) {
    $in_pod = 0;
    push @new_file, $cur_line;
    next;
  }

  if ( $cur_line =~ m/^=/ ) {
    $in_pod = 1;
    push @new_file, $cur_line;
    next;
  }

  if ( $prev_line =~ m/^ +/
    && $next_line =~ m/^ +/
    && $cur_line =~ m/^$/
    && $in_pod )
  {
    push @new_file, " $cur_line";
  }
  else {
    push @new_file, $cur_line;
  }
}

push @new_file, "";

open my $out, ">", $ARGV[0] or ie $!;
print $out join( "\n", @new_file );
close $out;
